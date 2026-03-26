@preconcurrency import CoreMotion
import Foundation

@MainActor
final class MotionActivityObservationCaptureService: ObservationCapturing {
    private let recorder: ObservationIngesting
    private let activityManager: CMMotionActivityManager

    private(set) var isCapturing: Bool = false

    init(recorder: ObservationIngesting) {
        self.recorder = recorder
        self.activityManager = CMMotionActivityManager()
    }

    func start() async throws {
        guard CMMotionActivityManager.isActivityAvailable(), isCapturing == false else {
            return
        }

        isCapturing = true

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else {
                return
            }

            Task { @MainActor in
                try? self.record(activity: activity)
            }
        }
    }

    func stop() {
        guard isCapturing else {
            return
        }

        isCapturing = false
        activityManager.stopActivityUpdates()
    }

    private func record(activity: CMMotionActivity) throws {
        let input = ObservationInput(
            timestamp: activity.startDate,
            sourceDevice: .iPhone,
            sourceType: .motion,
            payload: activityPayload(for: activity),
            qualityHint: confidenceHint(for: activity.confidence)
        )

        try recorder.record(input)
    }

    private func activityPayload(for activity: CMMotionActivity) -> String {
        [
            "stationary=\(activity.stationary)",
            "walking=\(activity.walking)",
            "running=\(activity.running)",
            "cycling=\(activity.cycling)",
            "automotive=\(activity.automotive)",
            "unknown=\(activity.unknown)",
        ]
        .joined(separator: ";")
    }

    private func confidenceHint(for confidence: CMMotionActivityConfidence) -> String? {
        switch confidence {
        case .low:
            "low-confidence"
        case .medium:
            "medium-confidence"
        case .high:
            nil
        @unknown default:
            "unknown-confidence"
        }
    }
}
