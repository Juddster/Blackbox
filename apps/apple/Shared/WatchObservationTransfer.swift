import Foundation

struct WatchObservationTransferEnvelope: Codable {
    static let payloadKey = "watchObservationBatch"
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let sentAt: Date
    let observations: [WatchObservationTransfer]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        sentAt: Date = .now,
        observations: [WatchObservationTransfer]
    ) {
        self.schemaVersion = schemaVersion
        self.sentAt = sentAt
        self.observations = observations
    }
}

struct WatchObservationTransfer: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sourceType: ObservationSourceType
    let payload: String
    let qualityHint: String?
    let ingestedAt: Date?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        sourceType: ObservationSourceType,
        payload: String,
        qualityHint: String? = nil,
        ingestedAt: Date? = .now
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourceType = sourceType
        self.payload = payload
        self.qualityHint = qualityHint
        self.ingestedAt = ingestedAt
    }
}
