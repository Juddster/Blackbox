import Foundation
import SwiftData

@MainActor
struct LocalSegmentTombstoner {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func tombstone(segmentID: UUID) throws {
        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        guard let record = records.first(where: { $0.id == segmentID }) else {
            return
        }

        record.lifecycleState = .deleted
        record.updatedAt = .now

        if let syncState = record.syncState {
            syncState.lastModifiedByDeviceID = "apple-local"
            syncState.lastModifiedAt = .now
            syncState.isDeleted = true
            syncState.disposition = .pendingUpload
            syncState.lastSyncError = nil
            syncState.pendingServerEnvelopeData = nil
        } else {
            record.syncState = SegmentSyncStateRecord(
                lastModifiedByDeviceID: "apple-local",
                lastModifiedAt: .now,
                syncVersion: 0,
                isDeleted: true,
                disposition: .pendingUpload
            )
        }

        try modelContext.save()
    }
}
