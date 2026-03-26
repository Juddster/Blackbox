import Foundation

enum SyncProjection {
    static func summary(from records: [SegmentRecord]) -> SyncSummary {
        let pendingUploadCount = records.count { $0.syncState?.disposition == .pendingUpload }
        let conflictedRecords = records.filter { $0.syncState?.disposition == .conflicted }

        return SyncSummary(
            pendingUploadCount: pendingUploadCount,
            conflictedCount: conflictedRecords.count,
            conflicts: conflictedRecords.map {
                SyncConflictSnapshot(
                    id: $0.id,
                    title: $0.title,
                    message: conflictMessage(for: $0.syncState?.lastSyncError)
                )
            }
        )
    }

    private static func conflictMessage(for error: String?) -> String {
        switch error {
        case "versionMismatch":
            return "Server has a newer version."
        case "deletedOnServer":
            return "Server deleted this segment."
        case let error?:
            return error
        case nil:
            return "Sync conflict needs review."
        }
    }
}
