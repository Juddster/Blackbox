import Foundation

enum InterpretationOrigin: String, Codable, CaseIterable, Identifiable {
    case system
    case user
    case mixed

    var id: String { rawValue }
}
