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
        let activities = await historicalActivities(from: startDate, to: endDate)
        guard let activities else {
            return nil
        }

        let inputs = activities.map { activity in
            ObservationInput(
                timestamp: activity.startDate,
                sourceDevice: .iPhone,
                sourceType: .motion,
                payload: activityPayload(for: activity, isHistorical: true),
                qualityHint: confidenceHint(for: activity.confidence)
            )
        }

        do {
            if inputs.isEmpty == false {
                try self.recorder.record(inputs)
            }
            return inputs.count
        } catch {
            return nil
        }
    }

    func historicalActivityCount(from startDate: Date, to endDate: Date) async -> Int? {
        let activities = await historicalActivities(from: startDate, to: endDate)
        return activities?.count
    }

    private func historicalActivities(from startDate: Date, to endDate: Date) async -> [CMMotionActivity]? {
        guard CMMotionActivityManager.isActivityAvailable(), endDate > startDate else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(from: startDate, to: endDate, to: .main) { [weak self] activities, error in
                guard self != nil else {
                    continuation.resume(returning: nil)
                    return
                }

                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: activities ?? [])
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
        activityPayload(
            for: activity,
            isHistorical: false
        )
    }

    private func activityPayload(for activity: CMMotionActivity, isHistorical: Bool) -> String {
        var components = [
            "stationary=\(activity.stationary)",
            "walking=\(activity.walking)",
            "running=\(activity.running)",
            "cycling=\(activity.cycling)",
            "automotive=\(activity.automotive)",
            "unknown=\(activity.unknown)",
        ]

        if isHistorical {
            components.append("historical=true")
            components.append("origin=systemHistory")
        } else {
            components.append("origin=live")
        }

        return components.joined(separator: ";")
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
