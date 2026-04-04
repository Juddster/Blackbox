import Foundation

struct ObservationInput: Sendable {
    let id: UUID?
    let timestamp: Date
    let sourceDevice: ObservationSourceDevice
    let sourceType: ObservationSourceType
    let payload: String
    let qualityHint: String?
    let ingestedAt: Date

    init(
        id: UUID? = nil,
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
}
