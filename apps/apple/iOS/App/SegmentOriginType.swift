import Foundation

enum SegmentOriginType: String, Codable, CaseIterable, Identifiable {
    case system
    case userCreated
    case merged
    case splitResult

    var id: String { rawValue }
}
