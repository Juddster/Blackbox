import Foundation

enum CaptureServiceKind: String, CaseIterable, Identifiable {
    case location
    case motionActivity
    case pedometer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .location:
            "Location"
        case .motionActivity:
            "Motion Activity"
        case .pedometer:
            "Pedometer"
        }
    }

    var systemImage: String {
        switch self {
        case .location:
            "location.fill"
        case .motionActivity:
            "figure.walk.motion"
        case .pedometer:
            "figure.walk"
        }
    }
}
