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
        let locationDistanceMeters = locationDistanceMeters(from: sortedObservations)
        let pedometerDistanceMeters = pedometerDistanceMeters(from: sortedObservations)

        let preferredDistanceMeters: Double?
        switch preferredActivityClass {
        case .running, .walking, .hiking:
            preferredDistanceMeters = pedometerDistanceMeters ?? locationDistanceMeters
        default:
            preferredDistanceMeters = locationDistanceMeters ?? pedometerDistanceMeters
        }

        return SegmentDistanceBreakdown(
            preferredDistanceMeters: preferredDistanceMeters,
            locationDistanceMeters: locationDistanceMeters,
            pedometerDistanceMeters: pedometerDistanceMeters
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

    private static func pedometerDistanceMeters(from observations: [ObservationRecord]) -> Double? {
        observations
            .filter { $0.sourceType == .pedometer }
            .compactMap { payloadValues(from: $0.payload)["distance"].flatMap(Double.init) }
            .max()
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
