import Foundation

enum SegmentLifecycleState: String, Codable, CaseIterable, Identifiable {
    case active
    case unsettled
    case settled
    case deleted

    var id: String { rawValue }
}
