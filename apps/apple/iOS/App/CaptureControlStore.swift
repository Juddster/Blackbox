import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CaptureControlStore {
    var isLocationCapturing = false
    var isMotionCapturing = false
    var isPedometerCapturing = false
    var statusMessage: String?
    var warningMessage: String?

    private var locationCaptureService: LocationObservationCaptureService?
    private var motionCaptureService: MotionActivityObservationCaptureService?
    private var pedometerCaptureService: PedometerObservationCaptureService?
    private var hasAppliedInitialResume = false

    private let defaults: UserDefaults

    private enum Keys {
        static let locationEnabled = "capture.location.enabled"
        static let motionEnabled = "capture.motion.enabled"
        static let pedometerEnabled = "capture.pedometer.enabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func configure(modelContext: ModelContext) {
        guard locationCaptureService == nil, motionCaptureService == nil, pedometerCaptureService == nil else {
            return
        }

        let recorder = LocalObservationRecorder(modelContext: modelContext)
        locationCaptureService = LocationObservationCaptureService(recorder: recorder)
        motionCaptureService = MotionActivityObservationCaptureService(recorder: recorder)
        pedometerCaptureService = PedometerObservationCaptureService(recorder: recorder)
    }

    func resumeIfNeeded() async {
        guard hasAppliedInitialResume == false else {
            return
        }

        hasAppliedInitialResume = true

        let shouldResumeLocation = defaults.bool(forKey: Keys.locationEnabled)
        let shouldResumeMotion = defaults.bool(forKey: Keys.motionEnabled)
        let shouldResumePedometer = defaults.bool(forKey: Keys.pedometerEnabled)

        if shouldResumeLocation || shouldResumeMotion || shouldResumePedometer {
            warningMessage = "Background collection may have been suspended while the app was not running. Blackbox is resuming collection now."
        }

        if shouldResumeLocation {
            await startLocationCapture()
        }

        if shouldResumeMotion {
            await startMotionCapture()
        }

        if shouldResumePedometer {
            await startPedometerCapture()
        }
    }

    func startLocationCapture() async {
        guard let locationCaptureService else {
            statusMessage = "Capture services are not configured yet."
            return
        }

        do {
            try await locationCaptureService.start()
            isLocationCapturing = locationCaptureService.isCapturing
            defaults.set(isLocationCapturing, forKey: Keys.locationEnabled)
            statusMessage = isLocationCapturing
                ? "Location capture started."
                : "Location capture was not started."
        } catch {
            statusMessage = "Location capture failed to start."
        }
    }

    func stopLocationCapture() {
        guard let locationCaptureService else {
            return
        }

        locationCaptureService.stop()
        isLocationCapturing = false
        defaults.set(false, forKey: Keys.locationEnabled)
        statusMessage = "Location capture stopped."
    }

    func startMotionCapture() async {
        guard let motionCaptureService else {
            statusMessage = "Capture services are not configured yet."
            return
        }

        do {
            try await motionCaptureService.start()
            isMotionCapturing = motionCaptureService.isCapturing
            defaults.set(isMotionCapturing, forKey: Keys.motionEnabled)
            statusMessage = isMotionCapturing
                ? "Motion capture started."
                : "Motion capture was not started."
        } catch {
            statusMessage = "Motion capture failed to start."
        }
    }

    func stopMotionCapture() {
        guard let motionCaptureService else {
            return
        }

        motionCaptureService.stop()
        isMotionCapturing = false
        defaults.set(false, forKey: Keys.motionEnabled)
        statusMessage = "Motion capture stopped."
    }

    func startPedometerCapture() async {
        guard let pedometerCaptureService else {
            statusMessage = "Capture services are not configured yet."
            return
        }

        do {
            try await pedometerCaptureService.start()
            isPedometerCapturing = pedometerCaptureService.isCapturing
            defaults.set(isPedometerCapturing, forKey: Keys.pedometerEnabled)
            statusMessage = isPedometerCapturing
                ? "Pedometer capture started."
                : "Pedometer capture was not started."
        } catch {
            statusMessage = "Pedometer capture failed to start."
        }
    }

    func stopPedometerCapture() {
        guard let pedometerCaptureService else {
            return
        }

        pedometerCaptureService.stop()
        isPedometerCapturing = false
        defaults.set(false, forKey: Keys.pedometerEnabled)
        statusMessage = "Pedometer capture stopped."
    }
}
