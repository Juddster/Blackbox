import Foundation
import SwiftData

@Model
final class ObservationRecord {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var sourceDevice: ObservationSourceDevice
    var sourceType: ObservationSourceType
    var payload: String
    var qualityHint: String?
    var ingestedAt: Date

    init(
        id: UUID = UUID(),
        timestamp: Date,
        sourceDevice: ObservationSourceDevice,
        sourceType: ObservationSourceType,
        payload: String,
        qualityHint: String? = nil,
        ingestedAt: Date = .now
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourceDevice = sourceDevice
        self.sourceType = sourceType
        self.payload = payload
        self.qualityHint = qualityHint
        self.ingestedAt = ingestedAt
    }

    convenience init(
        id: UUID = UUID(),
        input: ObservationInput
    ) {
        self.init(
            id: input.id ?? id,
            timestamp: input.timestamp,
            sourceDevice: input.sourceDevice,
            sourceType: input.sourceType,
            payload: input.payload,
            qualityHint: input.qualityHint,
            ingestedAt: input.ingestedAt
        )
    }
}
