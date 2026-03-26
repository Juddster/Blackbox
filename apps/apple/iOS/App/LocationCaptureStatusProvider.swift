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

        let authorizationState = authorizationState(for: CLLocationManager().authorizationStatus)
        return CaptureServiceStatus(
            kind: kind,
            isAvailable: true,
            authorizationState: authorizationState,
            note: nil
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
}
