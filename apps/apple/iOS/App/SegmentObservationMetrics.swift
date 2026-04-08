import CoreLocation
import Foundation

struct SegmentLocationFix: Identifiable {
    let observationID: UUID
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let horizontalAccuracy: Double?
    let speedMetersPerSecond: Double?
    let isManual: Bool

    var id: UUID { observationID }
}

struct SegmentDistanceBreakdown {
    let preferredDistanceMeters: Double?
    let locationDistanceMeters: Double?
    let pedometerDistanceMeters: Double?
    let iPhonePedometerDistanceMeters: Double?
    let watchPedometerDistanceMeters: Double?
}

struct SegmentPathReview {
    let rawFixes: [SegmentLocationFix]
    let acceptedFixes: [SegmentLocationFix]
    let rejectedFixes: [SegmentLocationFix]
    let rejectedDistanceMeters: Double
}

struct HealthWorkoutSummary {
    let uuid: UUID
    let startTime: Date
    let endTime: Date
    let distanceMeters: Double?
}

enum SegmentObservationMetrics {
    static func derivedDistanceMeters(from observations: [ObservationRecord]) -> Double? {
        distanceBreakdown(from: observations, preferredActivityClass: nil).preferredDistanceMeters
    }

    static func distanceBreakdown(
        from observations: [ObservationRecord],
        preferredActivityClass: ActivityClass?
    ) -> SegmentDistanceBreakdown {
        let sortedObservations = observations.sorted { $0.timestamp < $1.timestamp }
        let workoutDistanceMeters = authoritativeWorkoutSummary(from: sortedObservations)?.distanceMeters
        let locationDistanceMeters = locationDistanceMeters(from: sortedObservations)
        let pedometerDistancesByDevice = pedometerDistanceMetersByDevice(from: sortedObservations)
        let iPhonePedometerDistanceMeters = pedometerDistancesByDevice[.iPhone]
        let watchPedometerDistanceMeters = pedometerDistancesByDevice[.watch]
        let pedometerDistanceMeters = preferredPedometerDistance(
            iPhoneDistanceMeters: iPhonePedometerDistanceMeters,
            watchDistanceMeters: watchPedometerDistanceMeters
        )

        let preferredDistanceMeters: Double?
        if let workoutDistanceMeters {
            preferredDistanceMeters = workoutDistanceMeters
        } else {
            switch preferredActivityClass {
            case .running, .walking, .hiking:
                preferredDistanceMeters = pedometerDistanceMeters ?? locationDistanceMeters
            default:
                preferredDistanceMeters = locationDistanceMeters ?? pedometerDistanceMeters
            }
        }

        return SegmentDistanceBreakdown(
            preferredDistanceMeters: preferredDistanceMeters,
            locationDistanceMeters: locationDistanceMeters,
            pedometerDistanceMeters: pedometerDistanceMeters,
            iPhonePedometerDistanceMeters: iPhonePedometerDistanceMeters,
            watchPedometerDistanceMeters: watchPedometerDistanceMeters
        )
    }

    static func locationCoordinates(from observations: [ObservationRecord]) -> [CLLocationCoordinate2D] {
        locationFixes(from: observations).map(\.coordinate)
    }

    static func locationFixes(from observations: [ObservationRecord]) -> [SegmentLocationFix] {
        observations
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap(locationFix(from:))
    }

    static func pathReview(from observations: [ObservationRecord]) -> SegmentPathReview {
        let rawFixes = locationFixes(from: observations)
        guard let firstFix = rawFixes.first else {
            return SegmentPathReview(
                rawFixes: [],
                acceptedFixes: [],
                rejectedFixes: [],
                rejectedDistanceMeters: 0
            )
        }

        var acceptedFixes = [firstFix]
        var rejectedFixes = [SegmentLocationFix]()
        var rejectedDistanceMeters = 0.0
        var previousAcceptedFix = firstFix

        for fix in rawFixes.dropFirst() {
            let previousLocation = CLLocation(
                latitude: previousAcceptedFix.coordinate.latitude,
                longitude: previousAcceptedFix.coordinate.longitude
            )
            let currentLocation = CLLocation(
                latitude: fix.coordinate.latitude,
                longitude: fix.coordinate.longitude
            )
            let distanceMeters = previousLocation.distance(from: currentLocation)
            let timeDelta = max(fix.timestamp.timeIntervalSince(previousAcceptedFix.timestamp), 1)
            let impliedSpeed = distanceMeters / timeDelta
            let shouldRejectJump =
                distanceMeters >= 2_000
                || (distanceMeters >= 250 && impliedSpeed >= 8.5)

            if shouldRejectJump {
                rejectedFixes.append(fix)
                rejectedDistanceMeters += distanceMeters
            } else {
                acceptedFixes.append(fix)
                previousAcceptedFix = fix
            }
        }

        return SegmentPathReview(
            rawFixes: rawFixes,
            acceptedFixes: acceptedFixes,
            rejectedFixes: rejectedFixes,
            rejectedDistanceMeters: rejectedDistanceMeters
        )
    }

    static func authoritativeWorkoutSummary(from observations: [ObservationRecord]) -> HealthWorkoutSummary? {
        let summaries = observations.compactMap(healthWorkoutSummary(from:))
        guard summaries.isEmpty == false else {
            return nil
        }

        return summaries.max { lhs, rhs in
            let lhsDuration = lhs.endTime.timeIntervalSince(lhs.startTime)
            let rhsDuration = rhs.endTime.timeIntervalSince(rhs.startTime)
            if lhsDuration == rhsDuration {
                return lhs.endTime < rhs.endTime
            }

            return lhsDuration < rhsDuration
        }
    }

    private static func locationDistanceMeters(from observations: [ObservationRecord]) -> Double? {
        let locations = observations.compactMap(locationCoordinate(from:))
        guard locations.count >= 2 else {
            return nil
        }

        return zip(locations, locations.dropFirst()).reduce(0) { partialResult, pair in
            let start = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let end = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return partialResult + start.distance(from: end)
        }
    }

    private static func pedometerDistanceMetersByDevice(
        from observations: [ObservationRecord]
    ) -> [ObservationSourceDevice: Double] {
        Dictionary(grouping: observations.filter { $0.sourceType == .pedometer }, by: \.sourceDevice)
            .compactMapValues { groupedObservations in
                groupedObservations
                    .compactMap { payloadValues(from: $0.payload)["distance"].flatMap(Double.init) }
                    .max()
            }
    }

    private static func preferredPedometerDistance(
        iPhoneDistanceMeters: Double?,
        watchDistanceMeters: Double?
    ) -> Double? {
        watchDistanceMeters ?? iPhoneDistanceMeters
    }

    private static func healthWorkoutSummary(from observation: ObservationRecord) -> HealthWorkoutSummary? {
        let values = payloadValues(from: observation.payload)
        guard
            let uuidString = values["healthWorkoutUUID"],
            let uuid = UUID(uuidString: uuidString),
            let startInterval = values["healthWorkoutStart"].flatMap(TimeInterval.init),
            let endInterval = values["healthWorkoutEnd"].flatMap(TimeInterval.init)
        else {
            return nil
        }

        return HealthWorkoutSummary(
            uuid: uuid,
            startTime: Date(timeIntervalSince1970: startInterval),
            endTime: Date(timeIntervalSince1970: endInterval),
            distanceMeters: values["healthWorkoutDistance"].flatMap(Double.init)
        )
    }

    static func payloadValues(from payload: String) -> [String: String] {
        payload.split(separator: ";").reduce(into: [String: String]()) { partialResult, pair in
            let components = pair.split(separator: "=", maxSplits: 1)
            guard components.count == 2 else {
                return
            }

            partialResult[String(components[0])] = String(components[1])
        }
    }

    private static func locationCoordinate(from observation: ObservationRecord) -> CLLocationCoordinate2D? {
        guard observation.sourceType == .location else {
            return nil
        }

        let values = payloadValues(from: observation.payload)
        guard
            let latitude = values["lat"].flatMap(Double.init),
            let longitude = values["lon"].flatMap(Double.init)
        else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func locationFix(from observation: ObservationRecord) -> SegmentLocationFix? {
        guard let coordinate = locationCoordinate(from: observation) else {
            return nil
        }

        let values = payloadValues(from: observation.payload)
        return SegmentLocationFix(
            observationID: observation.id,
            timestamp: observation.timestamp,
            coordinate: coordinate,
            horizontalAccuracy: values["hAcc"].flatMap(Double.init),
            speedMetersPerSecond: values["speed"].flatMap(Double.init),
            isManual: values["manual"] == "true"
        )
    }
}
