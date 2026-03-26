import Foundation

@MainActor
protocol SegmentSyncing {
    func push(_ envelopes: [SegmentEnvelope]) async throws -> SegmentPushOutcome
    func pull() async throws -> [SegmentEnvelope]
}
