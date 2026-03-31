import CoreLocation
import Foundation

struct ReplayInferencePreview {
    let bucketDurationSeconds: TimeInterval
    let proposedSegments: [ReplayInferenceSegment]
    let proposedTransitions: [ReplayInferenceTransition]
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

struct ReplayInferenceTransition: Identifiable {
    let id = UUID()
    let timestamp: Date
    let fromActivityClass: ActivityClass
    let toActivityClass: ActivityClass
    let confidence: Double
    let reasonSummary: String
}

enum ReplayInferenceAnalyzer {
    private static let bucketDurationSeconds: TimeInterval = 60
    private static let minimumMeaningfulSegmentDuration: TimeInterval = 3 * 60

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
        let smoothedBuckets = smooth(buckets: buckets)
        let proposedSegments = merge(buckets: smoothedBuckets)

        return ReplayInferencePreview(
            bucketDurationSeconds: bucketDurationSeconds,
            proposedSegments: proposedSegments,
            proposedTransitions: transitions(from: proposedSegments),
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

    private static func smooth(buckets: [ReplayInferenceBucket]) -> [ReplayInferenceBucket] {
        guard buckets.count >= 3 else {
            return buckets
        }

        var smoothedBuckets = buckets
        for index in 1..<(buckets.count - 1) {
            let previous = smoothedBuckets[index - 1]
            let current = smoothedBuckets[index]
            let next = smoothedBuckets[index + 1]

            guard
                current.activityClass == nil || current.activityClass == .stationary,
                let bridgedClass = previous.activityClass,
                bridgedClass == next.activityClass,
                bridgedClass != .stationary
            else {
                continue
            }

            smoothedBuckets[index].applyBridge(
                activityClass: bridgedClass,
                confidence: min(previous.confidence, next.confidence) * 0.85,
                reason: "bridged \(bridgedClass.rawValue) gap"
            )
        }

        return smoothedBuckets
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
        return merged.filter { segment in
            segment.endTime.timeIntervalSince(segment.startTime) >= minimumMeaningfulSegmentDuration
                || segment.activityClass == .running
        }
    }

    private static func transitions(from segments: [ReplayInferenceSegment]) -> [ReplayInferenceTransition] {
        guard segments.count >= 2 else {
            return []
        }

        return zip(segments, segments.dropFirst()).compactMap { previous, next in
            guard previous.activityClass != next.activityClass else {
                return nil
            }

            return ReplayInferenceTransition(
                timestamp: next.startTime,
                fromActivityClass: previous.activityClass,
                toActivityClass: next.activityClass,
                confidence: min(previous.confidence, next.confidence),
                reasonSummary: mergedReason(previous.reasonSummary, next.reasonSummary)
            )
        }
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

    fileprivate static func mergedReason(_ lhs: String, _ rhs: String) -> String {
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
    private var floorsAscendedSamples = [Double]()
    private var floorsDescendedSamples = [Double]()
    private var locationSampleCount = 0
    private var pedometerSampleCount = 0
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

    mutating func applyBridge(activityClass: ActivityClass, confidence: Double, reason: String) {
        self.activityClass = activityClass
        self.confidence = max(self.confidence, confidence)
        if reasonSummary.isEmpty {
            reasonSummary = reason
        } else if reasonSummary.contains(reason) == false {
            reasonSummary = ReplayInferenceAnalyzer.mergedReason(reasonSummary, reason)
        }
    }

    private mutating func addLocation(values: [String: String]) {
        guard
            let latitude = values["lat"].flatMap(Double.init),
            let longitude = values["lon"].flatMap(Double.init)
        else {
            return
        }

        locationSampleCount += 1
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
        pedometerSampleCount += 1

        if let distanceMeters = values["distance"].flatMap(Double.init) {
            pedometerDistanceSamples.append(distanceMeters)
        }

        if let cadence = values["currentCadence"].flatMap(Double.init), cadence > 0 {
            cadenceSamples.append(cadence)
        }

        if let floorsAscended = values["floorsAscended"].flatMap(Double.init) {
            floorsAscendedSamples.append(floorsAscended)
        }

        if let floorsDescended = values["floorsDescended"].flatMap(Double.init) {
            floorsDescendedSamples.append(floorsDescended)
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
        let floorsAscendedDelta = deltaValue(from: floorsAscendedSamples) ?? 0
        let floorsDescendedDelta = deltaValue(from: floorsDescendedSamples) ?? 0
        let verticalFloorsDelta = floorsAscendedDelta + floorsDescendedDelta
        let isVerticalTransportCandidate = verticalFloorsDelta >= 2
            && locationDistanceMeters < 40
            && sawAutomotiveMotion == false
            && (averageSpeedMetersPerSecond ?? 0) < 2.0
        let hasAffirmativeStationaryEvidence = sawStationaryMotion
            || locationSampleCount > 0
            || pedometerSampleCount > 1
        let hasMeaningfulOnFootEvidence = sawWalkingMotion
            || sawRunningMotion
            || (averageCadenceStepsPerSecond ?? 0) >= 1.2
            || (pedometerDistanceMeters ?? 0) >= 15
        let walkingMotionDominatesExit = sawWalkingMotion
            && sawRunningMotion == false
            && (averageCadenceStepsPerSecond ?? 0) < 2.6
            && (averageSpeedMetersPerSecond ?? 0) < 2.35

        if isVerticalTransportCandidate {
            activityClass = nil
            confidence = 0
            reasonSummary = "suppressed vertical-transport candidate"
            return
        } else if sawAutomotiveMotion || (averageSpeedMetersPerSecond ?? 0) >= 5.5 {
            proposedClass = .vehicle
            proposedConfidence = sawAutomotiveMotion ? 0.95 : 0.75
            if sawAutomotiveMotion { matchedReasons.append("motion=automotive") }
            if let averageSpeedMetersPerSecond, averageSpeedMetersPerSecond >= 5.5 {
                matchedReasons.append("speed>=5.5m/s")
            }
        } else if walkingMotionDominatesExit {
            proposedClass = .walking
            matchedReasons.append("motion=walking")
            matchedReasons.append("run-exit override")
            if let averageCadenceStepsPerSecond {
                matchedReasons.append(String(format: "cadence=%.2f", averageCadenceStepsPerSecond))
            }
            proposedConfidence = 0.9
        } else if sawRunningMotion
            || (averageCadenceStepsPerSecond ?? 0) >= 2.35
            || (
                (averageCadenceStepsPerSecond ?? 0) >= 2.15
                    && (averageSpeedMetersPerSecond ?? 0) >= 2.0
                    && (pedometerDistanceMeters ?? 0) >= 110
            )
            || (
                (averageSpeedMetersPerSecond ?? 0) >= 2.45
                    && (pedometerDistanceMeters ?? 0) >= 120
            ) {
            proposedClass = .running
            if sawRunningMotion { matchedReasons.append("motion=running") }
            if let averageCadenceStepsPerSecond, averageCadenceStepsPerSecond >= 2.35 {
                matchedReasons.append("cadence>=2.35")
            }
            if let averageSpeedMetersPerSecond, averageSpeedMetersPerSecond >= 2.45 {
                matchedReasons.append("speed>=2.45m/s")
            }
            if let pedometerDistanceMeters, pedometerDistanceMeters >= 110 {
                matchedReasons.append("pedometer>=110m/min")
            }
            proposedConfidence = min(0.98, 0.45 + (0.15 * Double(matchedReasons.count)))
        } else if sawWalkingMotion
            || (averageCadenceStepsPerSecond ?? 0) >= 1.35
            || (averageSpeedMetersPerSecond ?? 0) >= 0.7
            || ((pedometerDistanceMeters ?? 0) >= 20) {
            proposedClass = .walking
            if sawWalkingMotion { matchedReasons.append("motion=walking") }
            if let averageCadenceStepsPerSecond, averageCadenceStepsPerSecond >= 1.35 {
                matchedReasons.append("cadence>=1.35")
            }
            if let averageSpeedMetersPerSecond, averageSpeedMetersPerSecond >= 0.7 {
                matchedReasons.append("speed>=0.7m/s")
            }
            if let pedometerDistanceMeters, pedometerDistanceMeters >= 20 {
                matchedReasons.append("pedometer>=20m/min")
            }
            proposedConfidence = min(0.95, 0.35 + (0.12 * Double(matchedReasons.count)))
        } else if hasMeaningfulOnFootEvidence == false
            && hasAffirmativeStationaryEvidence
            && (
                sawStationaryMotion
                    || (
                        locationDistanceMeters < 20
                            && ((pedometerDistanceMeters ?? 0) < 8)
                            && ((averageSpeedMetersPerSecond ?? 0) < 0.35)
                            && ((averageCadenceStepsPerSecond ?? 0) < 0.8)
                    )
            ) {
            proposedClass = .stationary
            if sawStationaryMotion { matchedReasons.append("motion=stationary") }
            if locationDistanceMeters < 20 { matchedReasons.append("location<20m") }
            if let pedometerDistanceMeters, pedometerDistanceMeters < 8 {
                matchedReasons.append("pedometer<8m")
            }
            if let averageCadenceStepsPerSecond, averageCadenceStepsPerSecond < 0.8 {
                matchedReasons.append("cadence<0.8")
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

    private func deltaValue(from samples: [Double]) -> Double? {
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
