import CoreLocation
import Foundation

struct LocationCaptureStatusProvider: CaptureStatusProviding {
    let kind: CaptureServiceKind = .location

    func currentStatus() -> CaptureServiceStatus {
        let hasUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
            || Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") != nil

        guard hasUsageDescription else {
            return CaptureServiceStatus(
                kind: kind,
                isAvailable: false,
                authorizationState: .misconfigured,
                note: "Add a location usage description before requesting authorization."
            )
        }

        let authorizationStatus = CLLocationManager().authorizationStatus
        let authorizationState = authorizationState(for: authorizationStatus)
        return CaptureServiceStatus(
            kind: kind,
            isAvailable: true,
            authorizationState: authorizationState,
            note: note(
                for: authorizationStatus,
                authorizationState: authorizationState
            )
        )
    }

    private func authorizationState(for status: CLAuthorizationStatus) -> CaptureAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .authorizedAlways, .authorizedWhenInUse:
            .authorized
        @unknown default:
            .unknown
        }
    }

    private func note(
        for status: CLAuthorizationStatus,
        authorizationState: CaptureAuthorizationState
    ) -> String? {
        if supportsBackgroundLocationUpdates() == false {
            return "This build does not currently declare background location mode, so passive background location collection will not work yet."
        }

        switch status {
        case .authorizedWhenInUse:
            return "Location access is only While Using App. Blackbox needs Always access for passive background collection."
        case .authorizedAlways:
            return "Background location is permitted."
        case .denied:
            return "Location access is denied in Settings."
        case .restricted:
            return "Location access is restricted on this device."
        case .notDetermined:
            return "Request Always location access to enable passive background collection."
        @unknown default:
            return authorizationState == .unknown ? "Location authorization state is unknown." : nil
        }
    }

    private func supportsBackgroundLocationUpdates() -> Bool {
        guard let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else {
            return false
        }

        return backgroundModes.contains("location")
    }
}
