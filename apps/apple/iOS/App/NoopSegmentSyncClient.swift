import Foundation

@MainActor
struct NoopSegmentSyncClient: SegmentSyncing {
    func push(_ envelopes: [SegmentEnvelope]) async throws -> SegmentPushOutcome {
        let accepted = envelopes.map { envelope in
            AcceptedSegmentPush(
                segmentID: envelope.id,
                syncVersion: envelope.sync.syncVersion + 1,
                updatedAt: .now
            )
        }

        return SegmentPushOutcome(
            accepted: accepted,
            conflicts: []
        )
    }

    func pull() async throws -> [SegmentEnvelope] {
        []
    }
}
