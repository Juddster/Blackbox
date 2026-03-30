import CoreLocation
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
    private var modelContext: ModelContext?

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
        locationCaptureService?.enterBackgroundMode()

        let affectedSources = expectedSourcesForBackgroundAssessment()
        guard affectedSources.isEmpty == false else {
            clearPendingGap()
            return
        }

        defaults.set(Date.now.timeIntervalSince1970, forKey: Keys.expectedCaptureGapStart)
        defaults.set(affectedSources.map(\.rawValue), forKey: Keys.expectedCaptureGapKinds)
    }

    func handleDidBecomeActive() async -> CaptureResumeReport? {
        defer {
            clearPendingGap()
        }

        locationCaptureService?.enterForegroundMode()

        let startInterval = defaults.double(forKey: Keys.expectedCaptureGapStart)
        guard startInterval > 0 else {
            gapNotice = nil
            return nil
        }

        let kindValues = defaults.stringArray(forKey: Keys.expectedCaptureGapKinds) ?? []
        let affectedSources = kindValues.compactMap(CaptureServiceKind.init(rawValue:))
        guard affectedSources.isEmpty == false else {
            gapNotice = nil
            return nil
        }

        let startTime = Date(timeIntervalSince1970: startInterval)
        let endTime = Date.now
        guard endTime > startTime else {
            gapNotice = nil
            return nil
        }

        _ = await recoverQueryableSources(
            from: startTime,
            to: endTime,
            expectedSources: affectedSources
        )
        let blockingReasons = backgroundBlockingReasons(for: affectedSources)
        let sourceCounts = observationCounts(
            from: startTime,
            to: endTime,
            expectedSources: affectedSources
        )

        gapNotice = blockingReasons.isEmpty ? nil : CaptureGapNotice(
            startTime: startTime,
            endTime: endTime,
            recoveredSources: sourceCounts
                .filter { $0.count > 0 && $0.kind != CaptureServiceKind.location }
                .map(\.kind),
            blockingReasons: blockingReasons
        )

        return CaptureResumeReport(
            startTime: startTime,
            endTime: endTime,
            sourceCounts: sourceCounts,
            blockingReasons: blockingReasons
        )
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

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

    private func expectedSourcesForBackgroundAssessment() -> [CaptureServiceKind] {
        var sources = [CaptureServiceKind]()

        if defaults.bool(forKey: Keys.locationEnabled) {
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

    private func backgroundBlockingReasons(for sources: [CaptureServiceKind]) -> [String] {
        var reasons = [String]()

        if sources.contains(.location) {
            let authorizationStatus = CLLocationManager().authorizationStatus

            if supportsBackgroundLocationUpdates() == false {
                reasons.append("Background location is not enabled for this build.")
            } else if authorizationStatus == .authorizedWhenInUse {
                reasons.append("Location access is set to While Using App, which prevents background location collection.")
            } else if authorizationStatus == .denied {
                reasons.append("Location access is denied in Settings.")
            } else if authorizationStatus == .restricted {
                reasons.append("Location access is restricted on this device.")
            } else if authorizationStatus == .notDetermined {
                reasons.append("Background location permission has not been granted yet.")
            }
        }

        return reasons
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

    private func observationCounts(
        from startTime: Date,
        to endTime: Date,
        expectedSources: [CaptureServiceKind]
    ) -> [CaptureResumeSourceCount] {
        guard let modelContext else {
            return expectedSources.map { CaptureResumeSourceCount(kind: $0, count: 0) }
        }

        let descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            }
        )

        let observations = (try? modelContext.fetch(descriptor)) ?? []
        let countsBySource = Dictionary(grouping: observations, by: \.sourceType)
            .mapValues(\.count)

        return expectedSources.map { kind in
            CaptureResumeSourceCount(
                kind: kind,
                count: countsBySource[kind.observationSourceType] ?? 0
            )
        }
    }

    private func clearPendingGap() {
        defaults.removeObject(forKey: Keys.expectedCaptureGapStart)
        defaults.removeObject(forKey: Keys.expectedCaptureGapKinds)
    }
}

private extension CaptureServiceKind {
    var observationSourceType: ObservationSourceType {
        switch self {
        case .location:
            .location
        case .motionActivity:
            .motion
        case .pedometer:
            .pedometer
        }
    }
}
