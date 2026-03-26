import CoreMotion
import Foundation

struct MotionActivityCaptureStatusProvider: CaptureStatusProviding {
    let kind: CaptureServiceKind = .motionActivity

    func currentStatus() -> CaptureServiceStatus {
        let hasUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSMotionUsageDescription") != nil
        guard hasUsageDescription else {
            return CaptureServiceStatus(
                kind: kind,
                isAvailable: false,
                authorizationState: .misconfigured,
                note: "Add NSMotionUsageDescription before enabling motion capture."
            )
        }

        let isAvailable = CMMotionActivityManager.isActivityAvailable()
        let authorizationState = authorizationState(for: CMMotionActivityManager.authorizationStatus())

        return CaptureServiceStatus(
            kind: kind,
            isAvailable: isAvailable,
            authorizationState: isAvailable ? authorizationState : .unavailable,
            note: isAvailable ? nil : "Motion activity is unavailable on this device."
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
