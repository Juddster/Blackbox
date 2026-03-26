import Foundation

enum CaptureAuthorizationState: String, Identifiable {
    case unknown
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
    case misconfigured

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unknown:
            "Unknown"
        case .notDetermined:
            "Not Determined"
        case .authorized:
            "Authorized"
        case .denied:
            "Denied"
        case .restricted:
            "Restricted"
        case .unavailable:
            "Unavailable"
        case .misconfigured:
            "Missing Usage Description"
        }
    }
}
