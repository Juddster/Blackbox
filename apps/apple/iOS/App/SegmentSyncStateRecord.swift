import Foundation
import SwiftData

@Model
final class SegmentSyncStateRecord {
    @Attribute(.unique) var id: UUID
    var lastModifiedByDeviceID: String
    var lastModifiedAt: Date
    var syncVersion: Int
    var isDeleted: Bool
    var disposition: SyncDisposition
    var lastSyncError: String?
    var pendingServerEnvelopeData: Data?

    @Relationship(inverse: \SegmentRecord.syncState) var segment: SegmentRecord?

    init(
        id: UUID = UUID(),
        lastModifiedByDeviceID: String,
        lastModifiedAt: Date = .now,
        syncVersion: Int = 0,
        isDeleted: Bool = false,
        disposition: SyncDisposition = .pendingUpload,
        lastSyncError: String? = nil,
        pendingServerEnvelopeData: Data? = nil
    ) {
        self.id = id
        self.lastModifiedByDeviceID = lastModifiedByDeviceID
        self.lastModifiedAt = lastModifiedAt
        self.syncVersion = syncVersion
        self.isDeleted = isDeleted
        self.disposition = disposition
        self.lastSyncError = lastSyncError
        self.pendingServerEnvelopeData = pendingServerEnvelopeData
    }
}
