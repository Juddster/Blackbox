import Foundation

@MainActor
struct DemoSegmentSyncClient: SegmentSyncing {
    private static let deletedSegmentIDsKey = "demo-sync.deleted-segment-ids"

    func push(_ envelopes: [SegmentEnvelope]) async throws -> SegmentPushOutcome {
        var accepted = [AcceptedSegmentPush]()
        var conflicts = [ConflictedSegmentPush]()
        var deletedSegmentIDs = storedDeletedSegmentIDs()

        for envelope in envelopes {
            if let conflictReason = conflictReason(for: envelope) {
                conflicts.append(
                    ConflictedSegmentPush(
                        segmentID: envelope.id,
                        reason: conflictReason,
                        serverEnvelope: conflictedServerEnvelope(for: envelope, reason: conflictReason)
                    )
                )
            } else {
                if envelope.sync.isDeleted {
                    deletedSegmentIDs.insert(envelope.id.uuidString)
                } else {
                    deletedSegmentIDs.remove(envelope.id.uuidString)
                }
                accepted.append(
                    AcceptedSegmentPush(
                        segmentID: envelope.id,
                        syncVersion: max(envelope.sync.syncVersion + 1, 1),
                        updatedAt: .now
                    )
                )
            }
        }

        storeDeletedSegmentIDs(deletedSegmentIDs)

        return SegmentPushOutcome(
            accepted: accepted,
            conflicts: conflicts
        )
    }

    func pull() async throws -> [SegmentEnvelope] {
        let now = Date.now
        let segmentID = UUID(uuidString: "D0E29E42-8D64-4BEE-8C92-60B4F473A111") ?? UUID()
        guard storedDeletedSegmentIDs().contains(segmentID.uuidString) == false else {
            return []
        }
        let interpretationID = UUID(uuidString: "0B2501AA-07AE-4E77-AF56-C3B63802F001") ?? UUID()
        let summaryID = UUID(uuidString: "E9FD45AB-5A36-4A1A-A68A-A6681C6C7001") ?? UUID()

        return [
            SegmentEnvelope(
                segment: SegmentPayload(
                    id: segmentID,
                    startTime: now.addingTimeInterval(-60 * 90),
                    endTime: now.addingTimeInterval(-60 * 55),
                    lifecycleState: .settled,
                    originType: .system,
                    primaryDeviceHint: .iPhone,
                    title: "Server walk",
                    createdAt: now.addingTimeInterval(-60 * 90),
                    updatedAt: now.addingTimeInterval(-60 * 50)
                ),
                interpretation: SegmentInterpretationPayload(
                    id: interpretationID,
                    segmentID: segmentID,
                    visibleClass: .walking,
                    userSelectedClass: nil,
                    confidence: 0.84,
                    ambiguityState: .clear,
                    needsReview: false,
                    interpretationOrigin: .system,
                    updatedAt: now.addingTimeInterval(-60 * 50)
                ),
                summary: SegmentSummaryPayload(
                    id: summaryID,
                    segmentID: segmentID,
                    durationSeconds: 35 * 60,
                    distanceMeters: 2_850,
                    elevationGainMeters: 24,
                    averageSpeedMetersPerSecond: 1.35,
                    maxSpeedMetersPerSecond: 1.9,
                    pauseCount: 0,
                    updatedAt: now.addingTimeInterval(-60 * 50)
                ),
                sync: SyncMetadataPayload(
                    lastModifiedByDeviceID: "server-demo-device",
                    lastModifiedAt: now.addingTimeInterval(-60 * 50),
                    syncVersion: 4,
                    isDeleted: false
                )
            )
        ]
    }

    private func conflictReason(for envelope: SegmentEnvelope) -> String? {
        if envelope.segment.title.localizedCaseInsensitiveContains("commute")
            && envelope.sync.syncVersion < 2
        {
            return "deletedOnServer"
        }

        if envelope.sync.syncVersion == 1 {
            return "versionMismatch"
        }

        return nil
    }

    private func conflictedServerEnvelope(for envelope: SegmentEnvelope, reason: String) -> SegmentEnvelope {
        let now = Date.now

        return SegmentEnvelope(
            segment: SegmentPayload(
                id: envelope.segment.id,
                startTime: envelope.segment.startTime,
                endTime: envelope.segment.endTime,
                lifecycleState: reason == "deletedOnServer" ? .deleted : envelope.segment.lifecycleState,
                originType: envelope.segment.originType,
                primaryDeviceHint: envelope.segment.primaryDeviceHint,
                title: reason == "deletedOnServer" ? envelope.segment.title : envelope.segment.title + " (Server)",
                createdAt: envelope.segment.createdAt,
                updatedAt: now
            ),
            interpretation: envelope.interpretation.map {
                SegmentInterpretationPayload(
                    id: $0.id,
                    segmentID: $0.segmentID,
                    visibleClass: $0.visibleClass,
                    userSelectedClass: $0.userSelectedClass,
                    confidence: min($0.confidence + 0.05, 1.0),
                    ambiguityState: $0.ambiguityState,
                    needsReview: $0.needsReview,
                    interpretationOrigin: $0.interpretationOrigin,
                    updatedAt: now
                )
            },
            summary: envelope.summary,
            sync: SyncMetadataPayload(
                lastModifiedByDeviceID: "server-demo-device",
                lastModifiedAt: now,
                syncVersion: 2,
                isDeleted: reason == "deletedOnServer"
            )
        )
    }

    private func storedDeletedSegmentIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.deletedSegmentIDsKey) ?? [])
    }

    private func storeDeletedSegmentIDs(_ deletedSegmentIDs: Set<String>) {
        UserDefaults.standard.set(Array(deletedSegmentIDs).sorted(), forKey: Self.deletedSegmentIDsKey)
    }
}
