import Foundation

enum ObservationSourceDevice: String, Codable, CaseIterable, Identifiable {
    case iPhone
    case watch

    var id: String { rawValue }
}
