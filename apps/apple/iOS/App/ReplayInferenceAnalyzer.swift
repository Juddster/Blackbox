import CoreLocation
import Foundation

struct ReplayInferencePreview {
    let bucketDurationSeconds: TimeInterval
    let proposedSegments: [ReplayInferenceSegment]
    let locationFixCount: Int
    let motionRecordCount: Int
    let pedometerRecordCount: Int
}

struct ReplayInferenceSegment: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let activityClass: ActivityClass
    let confidence: Double
    let reasonSummary: String
    let locationDistanceMeters: Double
    let pedometerDistanceMeters: Double?
    let averageSpeedMetersPerSecond: Double?
    let averageCadenceStepsPerSecond: Double?
}

enum ReplayInferenceAnalyzer {
    private static let bucketDurationSeconds: TimeInterval = 60

    static func preview(
        from observations: [ObservationRecord],
        windowStart: Date,
        windowEnd: Date
    ) -> ReplayInferencePreview {
        let sortedObservations = observations.sorted { $0.timestamp < $1.timestamp }
        let buckets = makeBuckets(
            from: sortedObservations,
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        return ReplayInferencePreview(
            bucketDurationSeconds: bucketDurationSeconds,
            proposedSegments: merge(buckets: buckets),
            locationFixCount: sortedObservations.filter { $0.sourceType == .location }.count,
            motionRecordCount: sortedObservations.filter { $0.sourceType == .motion }.count,
            pedometerRecordCount: sortedObservations.filter { $0.sourceType == .pedometer }.count
        )
    }

    private static func makeBuckets(
        from observations: [ObservationRecord],
        windowStart: Date,
        windowEnd: Date
    ) -> [ReplayInferenceBucket] {
        guard windowEnd > windowStart else {
            return []
        }

        let bucketCount = max(1, Int(ceil(windowEnd.timeIntervalSince(windowStart) / bucketDurationSeconds)))
        var buckets = (0..<bucketCount).map { index in
            let startTime = windowStart.addingTimeInterval(Double(index) * bucketDurationSeconds)
            let endTime = min(windowEnd, startTime.addingTimeInterval(bucketDurationSeconds))
            return ReplayInferenceBucket(startTime: startTime, endTime: endTime)
        }

        for observation in observations {
            let offset = observation.timestamp.timeIntervalSince(windowStart)
            guard offset >= 0 else {
                continue
            }

            let bucketIndex = min(max(Int(offset / bucketDurationSeconds), 0), bucketCount - 1)
            buckets[bucketIndex].add(observation)
        }

        return buckets
    }

    private static func merge(buckets: [ReplayInferenceBucket]) -> [ReplayInferenceSegment] {
        let classified = buckets.compactMap { bucket -> ReplayInferenceClassifiedBucket? in
            guard let activityClass = bucket.activityClass else {
                return nil
            }

            return ReplayInferenceClassifiedBucket(
                startTime: bucket.startTime,
                endTime: bucket.endTime,
                activityClass: activityClass,
                confidence: bucket.confidence,
                reasonSummary: bucket.reasonSummary,
                locationDistanceMeters: bucket.locationDistanceMeters,
                pedometerDistanceMeters: bucket.pedometerDistanceMeters,
                averageSpeedMetersPerSecond: bucket.averageSpeedMetersPerSecond,
                averageCadenceStepsPerSecond: bucket.averageCadenceStepsPerSecond
            )
        }

        guard classified.isEmpty == false else {
            return []
        }

        var merged = [ReplayInferenceSegment]()
        var current = classified[0]

        for bucket in classified.dropFirst() {
            let gap = bucket.startTime.timeIntervalSince(current.endTime)
            if bucket.activityClass == current.activityClass && gap <= bucketDurationSeconds {
                current.endTime = bucket.endTime
                current.confidence = max(current.confidence, bucket.confidence)
                let currentPedometerDistance = current.pedometerDistanceMeters ?? 0
                let bucketPedometerDistance = bucket.pedometerDistanceMeters ?? 0
                current.averageSpeedMetersPerSecond = weightedAverage(
                    current.averageSpeedMetersPerSecond,
                    current.locationDistanceMeters,
                    bucket.averageSpeedMetersPerSecond,
                    bucket.locationDistanceMeters
                )
                current.averageCadenceStepsPerSecond = weightedAverage(
                    current.averageCadenceStepsPerSecond,
                    currentPedometerDistance,
                    bucket.averageCadenceStepsPerSecond,
                    bucketPedometerDistance
                )
                current.locationDistanceMeters += bucket.locationDistanceMeters
                current.pedometerDistanceMeters = currentPedometerDistance + bucketPedometerDistance
                current.reasonSummary = mergedReason(current.reasonSummary, bucket.reasonSummary)
            } else {
                merged.append(current.segment)
                current = bucket
            }
        }

        merged.append(current.segment)
        return merged
    }

    private static func weightedAverage(
        _ lhsValue: Double?,
        _ lhsWeight: Double,
        _ rhsValue: Double?,
        _ rhsWeight: Double
    ) -> Double? {
        switch (lhsValue, rhsValue) {
        case let (.some(lhsValue), .some(rhsValue)):
            let totalWeight = lhsWeight + rhsWeight
            guard totalWeight > 0 else {
                return (lhsValue + rhsValue) / 2
            }
            return ((lhsValue * lhsWeight) + (rhsValue * rhsWeight)) / totalWeight
        case let (.some(lhsValue), .none):
            return lhsValue
        case let (.none, .some(rhsValue)):
            return rhsValue
        case (.none, .none):
            return nil
        }
    }

    private static func mergedReason(_ lhs: String, _ rhs: String) -> String {
        let parts = Set(lhs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            .union(rhs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return parts.sorted().joined(separator: ", ")
    }
}

private struct ReplayInferenceBucket {
    let startTime: Date
    let endTime: Date

    private(set) var locationDistanceMeters: Double = 0
    private(set) var pedometerDistanceMeters: Double?
    private(set) var averageSpeedMetersPerSecond: Double?
    private(set) var averageCadenceStepsPerSecond: Double?
    private(set) var activityClass: ActivityClass?
    private(set) var confidence: Double = 0
    private(set) var reasonSummary = ""

    private var lastLocation: CLLocation?
    private var locationSpeedSamples = [Double]()
    private var pedometerDistanceSamples = [Double]()
    private var cadenceSamples = [Double]()
    private var sawRunningMotion = false
    private var sawWalkingMotion = false
    private var sawAutomotiveMotion = false
    private var sawStationaryMotion = false

    init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }

    mutating func add(_ observation: ObservationRecord) {
        let values = SegmentObservationMetrics.payloadValues(from: observation.payload)

        switch observation.sourceType {
        case .location:
            addLocation(values: values)
        case .motion:
            addMotion(values: values)
        case .pedometer:
            addPedometer(values: values)
        case .heartRate, .deviceState, .connectivity, .other:
            break
        }

        classify()
    }

    private mutating func addLocation(values: [String: String]) {
        guard
            let latitude = values["lat"].flatMap(Double.init),
            let longitude = values["lon"].flatMap(Double.init)
        else {
            return
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        if let lastLocation {
            locationDistanceMeters += lastLocation.distance(from: location)
        }
        self.lastLocation = location

        if let speedMetersPerSecond = values["speed"].flatMap(Double.init), speedMetersPerSecond >= 0 {
            locationSpeedSamples.append(speedMetersPerSecond)
        }
    }

    private mutating func addMotion(values: [String: String]) {
        sawRunningMotion = sawRunningMotion || values["running"] == "true"
        sawWalkingMotion = sawWalkingMotion || values["walking"] == "true"
        sawAutomotiveMotion = sawAutomotiveMotion || values["automotive"] == "true"
        sawStationaryMotion = sawStationaryMotion || values["stationary"] == "true"
    }

    private mutating func addPedometer(values: [String: String]) {
        if let distanceMeters = values["distance"].flatMap(Double.init) {
            pedometerDistanceSamples.append(distanceMeters)
        }

        if let cadence = values["currentCadence"].flatMap(Double.init), cadence > 0 {
            cadenceSamples.append(cadence)
        }
    }

    private mutating func classify() {
        pedometerDistanceMeters = deltaDistance(from: pedometerDistanceSamples)
        averageSpeedMetersPerSecond = locationSpeedSamples.isEmpty == false
            ? locationSpeedSamples.reduce(0, +) / Double(locationSpeedSamples.count)
            : fallbackSpeed()
        averageCadenceStepsPerSecond = cadenceSamples.isEmpty == false
            ? cadenceSamples.reduce(0, +) / Double(cadenceSamples.count)
            : nil

        var matchedReasons = [String]()
        var proposedClass: ActivityClass?
        var proposedConfidence = 0.2

        if sawAutomotiveMotion || (averageSpeedMetersPerSecond ?? 0) >= 5.5 {
            proposedClass = .vehicle
            proposedConfidence = sawAutomotiveMotion ? 0.95 : 0.75
            if sawAutomotiveMotion { matchedReasons.append("motion=automotive") }
            if let averageSpeedMetersPerSecond, averageSpeedMetersPerSecond >= 5.5 {
                matchedReasons.append("speed>=5.5m/s")
            }
        } else if sawRunningMotion
            || (averageCadenceStepsPerSecond ?? 0) >= 2.2
            || (averageSpeedMetersPerSecond ?? 0) >= 2.3
            || ((pedometerDistanceMeters ?? 0) >= 140 && (averageCadenceStepsPerSecond ?? 0) >= 1.8) {
            proposedClass = .running
            if sawRunningMotion { matchedReasons.append("motion=running") }
            if let averageCadenceStepsPerSecond, averageCadenceStepsPerSecond >= 2.2 {
                matchedReasons.append("cadence>=2.2")
            }
            if let averageSpeedMetersPerSecond, averageSpeedMetersPerSecond >= 2.3 {
                matchedReasons.append("speed>=2.3m/s")
            }
            if let pedometerDistanceMeters, pedometerDistanceMeters >= 140 {
                matchedReasons.append("pedometer>=140m/min")
            }
            proposedConfidence = min(0.98, 0.45 + (0.15 * Double(matchedReasons.count)))
        } else if sawWalkingMotion
            || (averageCadenceStepsPerSecond ?? 0) >= 1.0
            || (averageSpeedMetersPerSecond ?? 0) >= 0.7
            || ((pedometerDistanceMeters ?? 0) >= 35) {
            proposedClass = .walking
            if sawWalkingMotion { matchedReasons.append("motion=walking") }
            if let averageCadenceStepsPerSecond, averageCadenceStepsPerSecond >= 1.0 {
                matchedReasons.append("cadence>=1.0")
            }
            if let averageSpeedMetersPerSecond, averageSpeedMetersPerSecond >= 0.7 {
                matchedReasons.append("speed>=0.7m/s")
            }
            if let pedometerDistanceMeters, pedometerDistanceMeters >= 35 {
                matchedReasons.append("pedometer>=35m/min")
            }
            proposedConfidence = min(0.95, 0.35 + (0.12 * Double(matchedReasons.count)))
        } else if sawStationaryMotion
            || ((locationDistanceMeters < 20) && ((pedometerDistanceMeters ?? 0) < 10) && ((averageSpeedMetersPerSecond ?? 0) < 0.4)) {
            proposedClass = .stationary
            if sawStationaryMotion { matchedReasons.append("motion=stationary") }
            if locationDistanceMeters < 20 { matchedReasons.append("location<20m") }
            if let pedometerDistanceMeters, pedometerDistanceMeters < 10 {
                matchedReasons.append("pedometer<10m")
            }
            proposedConfidence = min(0.9, 0.3 + (0.12 * Double(matchedReasons.count)))
        }

        activityClass = proposedClass
        confidence = proposedConfidence
        reasonSummary = matchedReasons.joined(separator: ", ")
    }

    private func deltaDistance(from samples: [Double]) -> Double? {
        guard let first = samples.first, let last = samples.last else {
            return nil
        }

        return max(0, last - first)
    }

    private func fallbackSpeed() -> Double? {
        let duration = endTime.timeIntervalSince(startTime)
        guard duration > 0, locationDistanceMeters > 0 else {
            return nil
        }

        return locationDistanceMeters / duration
    }
}

private struct ReplayInferenceClassifiedBucket {
    let startTime: Date
    var endTime: Date
    let activityClass: ActivityClass
    var confidence: Double
    var reasonSummary: String
    var locationDistanceMeters: Double
    var pedometerDistanceMeters: Double?
    var averageSpeedMetersPerSecond: Double?
    var averageCadenceStepsPerSecond: Double?

    var segment: ReplayInferenceSegment {
        ReplayInferenceSegment(
            startTime: startTime,
            endTime: endTime,
            activityClass: activityClass,
            confidence: confidence,
            reasonSummary: reasonSummary,
            locationDistanceMeters: locationDistanceMeters,
            pedometerDistanceMeters: pedometerDistanceMeters,
            averageSpeedMetersPerSecond: averageSpeedMetersPerSecond,
            averageCadenceStepsPerSecond: averageCadenceStepsPerSecond
        )
    }
}
