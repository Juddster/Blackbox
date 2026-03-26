import Foundation

struct SegmentPushOutcome {
    let accepted: [AcceptedSegmentPush]
    let conflicts: [ConflictedSegmentPush]

    var acceptedCount: Int { accepted.count }
    var conflictCount: Int { conflicts.count }
}

struct AcceptedSegmentPush {
    let segmentID: UUID
    let syncVersion: Int
    let updatedAt: Date
}

struct ConflictedSegmentPush {
    let segmentID: UUID
    let reason: String
    let serverEnvelope: SegmentEnvelope?
}
