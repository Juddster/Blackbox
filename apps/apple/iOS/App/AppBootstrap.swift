import Foundation
import SwiftData

@MainActor
enum AppBootstrap {
    static func seedIfNeeded(modelContext: ModelContext) throws {
        var segmentDescriptor = FetchDescriptor<SegmentRecord>()
        segmentDescriptor.fetchLimit = 1

        let existingSegments = try modelContext.fetch(segmentDescriptor)
        guard existingSegments.isEmpty else {
            return
        }

        let now = Date.now

        let morningWalk = SegmentRecord(
            startTime: now.addingTimeInterval(-60 * 60 * 8),
            endTime: now.addingTimeInterval(-60 * 60 * 7 - 60 * 20),
            lifecycleState: .settled,
            originType: .system,
            primaryDeviceHint: .iPhone,
            title: "Morning walk",
            interpretation: SegmentInterpretationRecord(
                visibleClass: .walking,
                confidence: 0.92,
                ambiguityState: .clear,
                needsReview: false,
                interpretationOrigin: .system
            ),
            summary: SegmentSummaryRecord(
                durationSeconds: 40 * 60,
                distanceMeters: 3_100,
                elevationGainMeters: 42,
                averageSpeedMetersPerSecond: 1.29,
                maxSpeedMetersPerSecond: 1.8
            ),
            syncState: SegmentSyncStateRecord(
                lastModifiedByDeviceID: "seed-phone",
                lastModifiedAt: now.addingTimeInterval(-60 * 60 * 7),
                syncVersion: 3,
                disposition: .synced
            )
        )

        let commute = SegmentRecord(
            startTime: now.addingTimeInterval(-60 * 60 * 3),
            endTime: now.addingTimeInterval(-60 * 60 * 2 - 60 * 25),
            lifecycleState: .unsettled,
            originType: .system,
            primaryDeviceHint: .iPhone,
            title: "Afternoon commute",
            interpretation: SegmentInterpretationRecord(
                visibleClass: .vehicle,
                confidence: 0.74,
                ambiguityState: .mixed,
                needsReview: true,
                interpretationOrigin: .system
            ),
            summary: SegmentSummaryRecord(
                durationSeconds: 35 * 60,
                distanceMeters: 18_400,
                averageSpeedMetersPerSecond: 8.76,
                maxSpeedMetersPerSecond: 21.1,
                pauseCount: 3
            ),
            syncState: SegmentSyncStateRecord(
                lastModifiedByDeviceID: "seed-phone",
                lastModifiedAt: now.addingTimeInterval(-60 * 60 * 2),
                syncVersion: 1,
                disposition: .pendingUpload
            )
        )

        let treadmillRun = SegmentRecord(
            startTime: now.addingTimeInterval(-60 * 60),
            endTime: now.addingTimeInterval(-60 * 20),
            lifecycleState: .active,
            originType: .userCreated,
            primaryDeviceHint: .watch,
            title: "Indoor run",
            interpretation: SegmentInterpretationRecord(
                visibleClass: .running,
                userSelectedClass: "running",
                confidence: 0.68,
                ambiguityState: .uncertain,
                needsReview: false,
                interpretationOrigin: .mixed
            ),
            summary: SegmentSummaryRecord(
                durationSeconds: 40 * 60,
                distanceMeters: 6_000,
                averageSpeedMetersPerSecond: 2.5,
                maxSpeedMetersPerSecond: 3.6
            ),
            syncState: SegmentSyncStateRecord(
                lastModifiedByDeviceID: "seed-watch",
                lastModifiedAt: now.addingTimeInterval(-60 * 20),
                syncVersion: 2,
                disposition: .conflicted,
                lastSyncError: "server version mismatch"
            )
        )

        let recorder = LocalObservationRecorder(modelContext: modelContext)

        let observations = [
            ObservationInput(
                timestamp: now.addingTimeInterval(-60 * 60 * 8),
                sourceDevice: .iPhone,
                sourceType: .location,
                payload: "seed.location.walk.start"
            ),
            ObservationInput(
                timestamp: now.addingTimeInterval(-60 * 60 * 3),
                sourceDevice: .iPhone,
                sourceType: .motion,
                payload: "seed.motion.vehicle.window"
            ),
            ObservationInput(
                timestamp: now.addingTimeInterval(-60 * 55),
                sourceDevice: .watch,
                sourceType: .heartRate,
                payload: "seed.hr.treadmill.window"
            ),
        ]

        modelContext.insert(morningWalk)
        modelContext.insert(commute)
        modelContext.insert(treadmillRun)
        try modelContext.save()
        try recorder.record(observations)
    }
}
