import Foundation

enum SyncDisposition: String, Codable, CaseIterable, Identifiable {
    case pendingUpload
    case synced
    case conflicted

    var id: String { rawValue }
}
