import Foundation

struct SegmentEnvelope: Identifiable, Codable {
    let segment: SegmentPayload
    let interpretation: SegmentInterpretationPayload?
    let summary: SegmentSummaryPayload?
    let sync: SyncMetadataPayload

    var id: UUID { segment.id }
}

struct SegmentPayload: Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let lifecycleState: SegmentLifecycleState
    let originType: SegmentOriginType
    let primaryDeviceHint: ObservationSourceDevice
    let title: String
    let createdAt: Date
    let updatedAt: Date
}

struct SegmentInterpretationPayload: Codable {
    let id: UUID
    let segmentID: UUID
    let visibleClass: ActivityClass
    let userSelectedClass: String?
    let confidence: Double
    let ambiguityState: AmbiguityState
    let needsReview: Bool
    let interpretationOrigin: InterpretationOrigin
    let updatedAt: Date
}

struct SegmentSummaryPayload: Codable {
    let id: UUID
    let segmentID: UUID
    let durationSeconds: TimeInterval
    let distanceMeters: Double?
    let locationDistanceMeters: Double?
    let pedometerDistanceMeters: Double?
    let elevationGainMeters: Double?
    let averageSpeedMetersPerSecond: Double?
    let maxSpeedMetersPerSecond: Double?
    let pauseCount: Int
    let updatedAt: Date
}

struct SyncMetadataPayload: Codable {
    let lastModifiedByDeviceID: String
    let lastModifiedAt: Date
    let syncVersion: Int
    let isDeleted: Bool
}
