import CoreLocation
import Foundation
import SwiftData

@MainActor
struct LocalUserSegmentWriter {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createSegment(
        startTime: Date,
        endTime: Date,
        activityClass: ActivityClass,
        narrowerLabel: String,
        distanceMeters: Double?
    ) throws {
        let trimmedLabel = narrowerLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationSeconds = max(0, endTime.timeIntervalSince(startTime))
        let derivedDistanceMeters = try derivedDistanceMeters(
            fallbackDistanceMeters: distanceMeters,
            startTime: startTime,
            endTime: endTime
        )
        let segment = SegmentRecord(
            startTime: startTime,
            endTime: endTime,
            lifecycleState: .settled,
            originType: .userCreated,
            primaryDeviceHint: .iPhone,
            title: title(for: activityClass, narrowerLabel: trimmedLabel)
        )

        segment.interpretation = SegmentInterpretationRecord(
            visibleClass: activityClass,
            userSelectedClass: trimmedLabel.isEmpty ? nil : trimmedLabel,
            confidence: 1,
            ambiguityState: .clear,
            needsReview: false,
            interpretationOrigin: .user
        )
        segment.summary = SegmentSummaryRecord(
            durationSeconds: durationSeconds,
            distanceMeters: derivedDistanceMeters,
            averageSpeedMetersPerSecond: averageSpeed(
                distanceMeters: derivedDistanceMeters,
                durationSeconds: durationSeconds
            )
        )
        segment.syncState = SegmentSyncStateRecord(
            lastModifiedByDeviceID: "apple-local",
            lastModifiedAt: .now,
            syncVersion: 0,
            disposition: .pendingUpload
        )

        modelContext.insert(segment)
        try modelContext.save()
    }

    private func title(for activityClass: ActivityClass, narrowerLabel: String) -> String {
        if narrowerLabel.isEmpty == false {
            return narrowerLabel.replacingOccurrences(of: "-", with: " ").localizedCapitalized
        }

        return activityClass.displayName
    }

    private func averageSpeed(distanceMeters: Double?, durationSeconds: TimeInterval) -> Double? {
        guard
            let distanceMeters,
            durationSeconds > 0
        else {
            return nil
        }

        return distanceMeters / durationSeconds
    }

    private func derivedDistanceMeters(
        fallbackDistanceMeters: Double?,
        startTime: Date,
        endTime: Date
    ) throws -> Double? {
        if let fallbackDistanceMeters {
            return fallbackDistanceMeters
        }

        let descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            },
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )
        let observations = try modelContext.fetch(descriptor)

        let locationDistance = locationDistanceMeters(from: observations)
        if let locationDistance, locationDistance > 0 {
            return locationDistance
        }

        return pedometerDistanceMeters(from: observations)
    }

    private func locationDistanceMeters(from observations: [ObservationRecord]) -> Double? {
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

    private func pedometerDistanceMeters(from observations: [ObservationRecord]) -> Double? {
        observations
            .filter { $0.sourceType == .pedometer }
            .compactMap { payloadValues(from: $0.payload)["distance"].flatMap(Double.init) }
            .max()
    }

    private func locationCoordinate(from observation: ObservationRecord) -> CLLocationCoordinate2D? {
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

    private func payloadValues(from payload: String) -> [String: String] {
        payload.split(separator: ";").reduce(into: [String: String]()) { partialResult, pair in
            let components = pair.split(separator: "=", maxSplits: 1)
            guard components.count == 2 else {
                return
            }

            partialResult[String(components[0])] = String(components[1])
        }
    }
}
