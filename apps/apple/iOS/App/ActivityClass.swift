import Foundation

enum ActivityClass: String, Codable, CaseIterable, Identifiable {
    case stationary
    case walking
    case running
    case cycling
    case hiking
    case vehicle
    case flight
    case waterActivity
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stationary:
            "Stationary"
        case .walking:
            "Walking"
        case .running:
            "Running"
        case .cycling:
            "Cycling"
        case .hiking:
            "Hiking"
        case .vehicle:
            "Vehicle"
        case .flight:
            "Flight"
        case .waterActivity:
            "Water Activity"
        case .unknown:
            "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .stationary:
            "pause.circle.fill"
        case .walking:
            "figure.walk"
        case .running:
            "figure.run"
        case .cycling:
            "figure.outdoor.cycle"
        case .hiking:
            "figure.hiking"
        case .vehicle:
            "car.fill"
        case .flight:
            "airplane"
        case .waterActivity:
            "water.waves"
        case .unknown:
            "questionmark.circle"
        }
    }
}
