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
    var gapNotice: CaptureGapNotice?

    private var locationCaptureService: LocationObservationCaptureService?
    private var motionCaptureService: MotionActivityObservationCaptureService?
    private var pedometerCaptureService: PedometerObservationCaptureService?
    private var hasAppliedInitialResume = false

    private let defaults: UserDefaults

    private enum Keys {
        static let locationEnabled = "capture.location.enabled"
        static let motionEnabled = "capture.motion.enabled"
        static let pedometerEnabled = "capture.pedometer.enabled"
        static let expectedCaptureGapStart = "capture.expected-gap.start"
        static let expectedCaptureGapKinds = "capture.expected-gap.kinds"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCaptureIntentEnabled: Bool {
        defaults.bool(forKey: Keys.locationEnabled)
            || defaults.bool(forKey: Keys.motionEnabled)
            || defaults.bool(forKey: Keys.pedometerEnabled)
    }

    func handleDidEnterBackground() {
        let affectedSources = expectedInterruptedSources()
        guard affectedSources.isEmpty == false else {
            clearPendingGap()
            return
        }

        defaults.set(Date.now.timeIntervalSince1970, forKey: Keys.expectedCaptureGapStart)
        defaults.set(affectedSources.map(\.rawValue), forKey: Keys.expectedCaptureGapKinds)
    }

    func handleDidBecomeActive() async {
        defer {
            clearPendingGap()
        }

        let startInterval = defaults.double(forKey: Keys.expectedCaptureGapStart)
        guard startInterval > 0 else {
            gapNotice = nil
            return
        }

        let kindValues = defaults.stringArray(forKey: Keys.expectedCaptureGapKinds) ?? []
        let affectedSources = kindValues.compactMap(CaptureServiceKind.init(rawValue:))
        guard affectedSources.isEmpty == false else {
            gapNotice = nil
            return
        }

        let startTime = Date(timeIntervalSince1970: startInterval)
        let endTime = Date.now
        guard endTime > startTime else {
            gapNotice = nil
            return
        }

        let recoveredSources = await recoverQueryableSources(
            from: startTime,
            to: endTime,
            expectedSources: affectedSources
        )
        let unresolvedSources = affectedSources.filter { recoveredSources.contains($0) == false }

        gapNotice = CaptureGapNotice(
            startTime: startTime,
            endTime: endTime,
            affectedSources: unresolvedSources,
            recoveredSources: recoveredSources
        )
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

    private func expectedInterruptedSources() -> [CaptureServiceKind] {
        var sources = [CaptureServiceKind]()

        if defaults.bool(forKey: Keys.locationEnabled), supportsBackgroundLocationUpdates() == false {
            sources.append(.location)
        }

        if defaults.bool(forKey: Keys.motionEnabled) {
            sources.append(.motionActivity)
        }

        if defaults.bool(forKey: Keys.pedometerEnabled) {
            sources.append(.pedometer)
        }

        return sources
    }

    private func recoverQueryableSources(
        from startTime: Date,
        to endTime: Date,
        expectedSources: [CaptureServiceKind]
    ) async -> [CaptureServiceKind] {
        var recoveredSources = [CaptureServiceKind]()

        if expectedSources.contains(.motionActivity),
           let motionCaptureService,
           let _ = await motionCaptureService.backfill(from: startTime, to: endTime) {
            recoveredSources.append(.motionActivity)
        }

        if expectedSources.contains(.pedometer),
           let pedometerCaptureService,
           await pedometerCaptureService.backfill(from: startTime, to: endTime) {
            recoveredSources.append(.pedometer)
        }

        return recoveredSources
    }

    private func supportsBackgroundLocationUpdates() -> Bool {
        guard let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else {
            return false
        }

        return backgroundModes.contains("location")
    }

    private func clearPendingGap() {
        defaults.removeObject(forKey: Keys.expectedCaptureGapStart)
        defaults.removeObject(forKey: Keys.expectedCaptureGapKinds)
    }
}
