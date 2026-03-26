import Foundation

enum CaptureProjection {
    static func currentStatuses() -> [CaptureServiceStatus] {
        let providers: [CaptureStatusProviding] = [
            LocationCaptureStatusProvider(),
            MotionActivityCaptureStatusProvider(),
            PedometerCaptureStatusProvider(),
        ]

        return providers.map { $0.currentStatus() }
    }
}
