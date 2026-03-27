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
            distanceMeters: distanceMeters,
            averageSpeedMetersPerSecond: averageSpeed(
                distanceMeters: distanceMeters,
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
}
