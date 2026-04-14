import Foundation
import SwiftData

struct LocalSegmentTombstoner: @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContext: ModelContext) {
        self.modelContainer = modelContext.container
    }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func tombstone(segmentID: UUID) throws {
        let modelContext = ModelContext(modelContainer)
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
        LocalDeletedSegmentStore.markDeleted(segmentID)
    }

    func tombstonePostedSystemSegments(startTime: Date, endTime: Date) throws -> Int {
        let modelContext = ModelContext(modelContainer)
        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>()).filter { segment in
            segment.originType == .system
                && segment.lifecycleState != .deleted
                && segment.endTime >= startTime
                && segment.startTime <= endTime
        }
        guard records.isEmpty == false else {
            return 0
        }

        for record in records {
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

            LocalDeletedSegmentStore.markDeleted(record.id)
        }

        try modelContext.save()
        return records.count
    }
}
