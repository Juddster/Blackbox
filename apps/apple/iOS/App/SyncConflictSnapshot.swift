import Foundation

struct SyncConflictSnapshot: Identifiable {
    let id: UUID
    let title: String
    let message: String
}
