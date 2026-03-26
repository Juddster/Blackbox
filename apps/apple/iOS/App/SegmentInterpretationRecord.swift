import Foundation
import SwiftData

@Model
final class SegmentInterpretationRecord {
    @Attribute(.unique) var id: UUID
    var visibleClass: ActivityClass
    var userSelectedClass: String?
    var confidence: Double
    var ambiguityState: AmbiguityState
    var needsReview: Bool
    var interpretationOrigin: InterpretationOrigin
    var updatedAt: Date

    @Relationship(inverse: \SegmentRecord.interpretation) var segment: SegmentRecord?

    init(
        id: UUID = UUID(),
        visibleClass: ActivityClass,
        userSelectedClass: String? = nil,
        confidence: Double,
        ambiguityState: AmbiguityState,
        needsReview: Bool,
        interpretationOrigin: InterpretationOrigin,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.visibleClass = visibleClass
        self.userSelectedClass = userSelectedClass
        self.confidence = confidence
        self.ambiguityState = ambiguityState
        self.needsReview = needsReview
        self.interpretationOrigin = interpretationOrigin
        self.updatedAt = updatedAt
    }
}
