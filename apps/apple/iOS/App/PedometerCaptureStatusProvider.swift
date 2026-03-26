import CoreMotion
import Foundation

struct PedometerCaptureStatusProvider: CaptureStatusProviding {
    let kind: CaptureServiceKind = .pedometer

    func currentStatus() -> CaptureServiceStatus {
        let hasUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSMotionUsageDescription") != nil
        guard hasUsageDescription else {
            return CaptureServiceStatus(
                kind: kind,
                isAvailable: false,
                authorizationState: .misconfigured,
                note: "Add NSMotionUsageDescription before enabling pedometer capture."
            )
        }

        let isAvailable = CMPedometer.isStepCountingAvailable()
        let authorizationState = authorizationState(for: CMPedometer.authorizationStatus())

        return CaptureServiceStatus(
            kind: kind,
            isAvailable: isAvailable,
            authorizationState: isAvailable ? authorizationState : .unavailable,
            note: isAvailable ? nil : "Pedometer data is unavailable on this device."
        )
    }

    private func authorizationState(for status: CMAuthorizationStatus) -> CaptureAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .authorized:
            .authorized
        @unknown default:
            .unknown
        }
    }
}
