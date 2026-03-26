import Foundation

enum ObservationSourceType: String, Codable, CaseIterable, Identifiable {
    case location
    case motion
    case pedometer
    case heartRate
    case deviceState
    case connectivity
    case other

    var id: String { rawValue }
}
