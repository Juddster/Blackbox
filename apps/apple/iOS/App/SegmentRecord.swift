import Foundation
import SwiftData

@Model
final class SegmentRecord {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date
    var lifecycleState: SegmentLifecycleState
    var originType: SegmentOriginType
    var primaryDeviceHint: ObservationSourceDevice
    var createdAt: Date
    var updatedAt: Date
    var title: String

    @Relationship(deleteRule: .cascade) var interpretation: SegmentInterpretationRecord?
    @Relationship(deleteRule: .cascade) var summary: SegmentSummaryRecord?
    @Relationship(deleteRule: .cascade) var syncState: SegmentSyncStateRecord?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        lifecycleState: SegmentLifecycleState,
        originType: SegmentOriginType,
        primaryDeviceHint: ObservationSourceDevice,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String,
        interpretation: SegmentInterpretationRecord? = nil,
        summary: SegmentSummaryRecord? = nil,
        syncState: SegmentSyncStateRecord? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.lifecycleState = lifecycleState
        self.originType = originType
        self.primaryDeviceHint = primaryDeviceHint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.interpretation = interpretation
        self.summary = summary
        self.syncState = syncState
    }
}
