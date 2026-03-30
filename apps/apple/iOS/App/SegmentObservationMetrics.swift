import CoreLocation
import Foundation

enum SegmentObservationMetrics {
    static func derivedDistanceMeters(from observations: [ObservationRecord]) -> Double? {
        let sortedObservations = observations.sorted { $0.timestamp < $1.timestamp }
        if let locationDistanceMeters = locationDistanceMeters(from: sortedObservations),
           locationDistanceMeters > 0 {
            return locationDistanceMeters
        }

        return pedometerDistanceMeters(from: sortedObservations)
    }

    static func locationCoordinates(from observations: [ObservationRecord]) -> [CLLocationCoordinate2D] {
        observations
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap(locationCoordinate(from:))
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

    private static func payloadValues(from payload: String) -> [String: String] {
        payload.split(separator: ";").reduce(into: [String: String]()) { partialResult, pair in
            let components = pair.split(separator: "=", maxSplits: 1)
            guard components.count == 2 else {
                return
            }

            partialResult[String(components[0])] = String(components[1])
        }
    }
}
