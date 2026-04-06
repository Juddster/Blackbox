import Foundation

struct WatchObservationTransferEnvelope: Codable {
    static let payloadKey = "watchObservationBatch"
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let captureSessionID: UUID
    let batchSequence: Int
    let sentAt: Date
    let senderAppVersion: String
    let senderBuildNumber: String
    let observations: [WatchObservationTransfer]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        captureSessionID: UUID,
        batchSequence: Int,
        sentAt: Date = .now,
        senderAppVersion: String,
        senderBuildNumber: String,
        observations: [WatchObservationTransfer]
    ) {
        self.schemaVersion = schemaVersion
        self.captureSessionID = captureSessionID
        self.batchSequence = batchSequence
        self.sentAt = sentAt
        self.senderAppVersion = senderAppVersion
        self.senderBuildNumber = senderBuildNumber
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
