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

    func backfill(from startDate: Date, to endDate: Date) async -> Int? {
        guard CMMotionActivityManager.isActivityAvailable(), endDate > startDate else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(from: startDate, to: endDate, to: .main) { [weak self] activities, error in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let inputs = (activities ?? []).map { activity in
                    ObservationInput(
                        timestamp: activity.startDate,
                        sourceDevice: .iPhone,
                        sourceType: .motion,
                        payload: self.activityPayload(for: activity),
                        qualityHint: self.confidenceHint(for: activity.confidence)
                    )
                }

                do {
                    if inputs.isEmpty == false {
                        try self.recorder.record(inputs)
                    }
                    continuation.resume(returning: inputs.count)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
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
