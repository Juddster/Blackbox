import Foundation

struct SyncSummary {
    let pendingUploadCount: Int
    let conflictedCount: Int
    let conflicts: [SyncConflictSnapshot]
}
