import Foundation

enum AmbiguityState: String, Codable, CaseIterable, Identifiable {
    case clear
    case mixed
    case uncertain

    var id: String { rawValue }
}
