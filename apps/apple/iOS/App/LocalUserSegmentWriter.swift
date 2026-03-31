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
        let distanceBreakdown = try distanceBreakdown(
            fallbackDistanceMeters: distanceMeters,
            activityClass: activityClass,
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
            distanceMeters: distanceBreakdown.preferredDistanceMeters,
            locationDistanceMeters: distanceBreakdown.locationDistanceMeters,
            pedometerDistanceMeters: distanceBreakdown.pedometerDistanceMeters,
            averageSpeedMetersPerSecond: averageSpeed(
                distanceMeters: distanceBreakdown.preferredDistanceMeters,
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

    func updateSegment(
        segmentID: UUID,
        startTime: Date,
        endTime: Date,
        activityClass: ActivityClass,
        narrowerLabel: String,
        distanceMeters: Double?
    ) throws {
        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        guard let segment = records.first(where: { $0.id == segmentID }) else {
            return
        }

        let trimmedLabel = narrowerLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationSeconds = max(0, endTime.timeIntervalSince(startTime))
        let distanceBreakdown = try distanceBreakdown(
            fallbackDistanceMeters: distanceMeters,
            activityClass: activityClass,
            startTime: startTime,
            endTime: endTime
        )

        segment.startTime = startTime
        segment.endTime = endTime
        segment.title = title(for: activityClass, narrowerLabel: trimmedLabel)
        segment.updatedAt = .now

        if let interpretation = segment.interpretation {
            interpretation.visibleClass = activityClass
            interpretation.userSelectedClass = trimmedLabel.isEmpty ? nil : trimmedLabel
            interpretation.confidence = 1
            interpretation.ambiguityState = .clear
            interpretation.needsReview = false
            interpretation.interpretationOrigin = .user
            interpretation.updatedAt = .now
        } else {
            segment.interpretation = SegmentInterpretationRecord(
                visibleClass: activityClass,
                userSelectedClass: trimmedLabel.isEmpty ? nil : trimmedLabel,
                confidence: 1,
                ambiguityState: .clear,
                needsReview: false,
                interpretationOrigin: .user
            )
        }

        if let summary = segment.summary {
            summary.durationSeconds = durationSeconds
            summary.distanceMeters = distanceBreakdown.preferredDistanceMeters
            summary.locationDistanceMeters = distanceBreakdown.locationDistanceMeters
            summary.pedometerDistanceMeters = distanceBreakdown.pedometerDistanceMeters
            summary.averageSpeedMetersPerSecond = averageSpeed(
                distanceMeters: distanceBreakdown.preferredDistanceMeters,
                durationSeconds: durationSeconds
            )
            summary.updatedAt = .now
        } else {
            segment.summary = SegmentSummaryRecord(
                durationSeconds: durationSeconds,
                distanceMeters: distanceBreakdown.preferredDistanceMeters,
                locationDistanceMeters: distanceBreakdown.locationDistanceMeters,
                pedometerDistanceMeters: distanceBreakdown.pedometerDistanceMeters,
                averageSpeedMetersPerSecond: averageSpeed(
                    distanceMeters: distanceBreakdown.preferredDistanceMeters,
                    durationSeconds: durationSeconds
                )
            )
        }

        if let syncState = segment.syncState {
            syncState.lastModifiedByDeviceID = "apple-local"
            syncState.lastModifiedAt = .now
            syncState.disposition = .pendingUpload
            syncState.lastSyncError = nil
        } else {
            segment.syncState = SegmentSyncStateRecord(
                lastModifiedByDeviceID: "apple-local",
                lastModifiedAt: .now,
                syncVersion: 0,
                disposition: .pendingUpload
            )
        }

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

    private func distanceBreakdown(
        fallbackDistanceMeters: Double?,
        activityClass: ActivityClass,
        startTime: Date,
        endTime: Date
    ) throws -> SegmentDistanceBreakdown {
        if let fallbackDistanceMeters {
            return SegmentDistanceBreakdown(
                preferredDistanceMeters: fallbackDistanceMeters,
                locationDistanceMeters: nil,
                pedometerDistanceMeters: nil
            )
        }

        let descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            },
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )
        let observations = try modelContext.fetch(descriptor)

        return SegmentObservationMetrics.distanceBreakdown(
            from: observations,
            preferredActivityClass: activityClass
        )
    }
}
