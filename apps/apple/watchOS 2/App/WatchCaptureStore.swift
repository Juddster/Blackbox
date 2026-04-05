@preconcurrency import CoreLocation
@preconcurrency import CoreMotion
import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchCaptureStore {
    static let shared = WatchCaptureStore()

    var isCapturing = false
    var sessionSummary = "Not Connected"
    var sessionImageName = "applewatch.slash"
    var statusNote: String?
    var pendingObservationCount = 0
    var totalQueuedObservationCount = 0
    var totalTransferredObservationCount = 0
    var flushAttemptCount = 0
    var deferredFlushCount = 0
    var locationObservationCount = 0
    var pedometerObservationCount = 0
    var motionObservationCount = 0
    var lastTransferSummary: String?
    var lastFlushSummary: String?
    var autoCaptureEnabled = UserDefaults.standard.bool(forKey: "watch.autoCaptureEnabled")
    var captureSummary = "Idle"

    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private let motionActivityManager = CMMotionActivityManager()
    private let session = WCSession.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let autoCaptureEnabledKey = "watch.autoCaptureEnabled"

    private var delegateProxy: WatchCaptureDelegateProxy?
    private var pendingObservations: [WatchObservationTransfer] = []
    private var locationAuthorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var lastFlushDate: Date?
    private var isStartingCapture = false

    func configureIfNeeded() async {
        guard delegateProxy == nil else {
            refreshSessionState()
            return
        }

        let proxy = WatchCaptureDelegateProxy()
        proxy.onActivationChange = { [weak self] _, error in
            Task { @MainActor in
                self?.refreshSessionState()
                if let error {
                    self?.statusNote = "Watch session activation failed: \(error.localizedDescription)"
                }
            }
        }
        proxy.onReachabilityChange = { [weak self] in
            Task { @MainActor in
                self?.refreshSessionState()
            }
        }
        proxy.onLocationAuthorizationChange = { [weak self] status in
            self?.resumeLocationAuthorization(status)
        }
        proxy.onLocations = { [weak self] locations in
            Task { @MainActor in
                self?.recordLocations(locations)
            }
        }
        proxy.onLocationFailure = { [weak self] error in
            Task { @MainActor in
                self?.handleLocationFailure(error)
            }
        }

        delegateProxy = proxy
        locationManager.delegate = proxy
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .otherNavigation
        session.delegate = proxy
        session.activate()
        refreshSessionState()

        if autoCaptureEnabled {
            await restorePassiveCaptureIfNeeded()
        }
    }

    func startCapture() async {
        guard isStartingCapture == false else {
            return
        }

        isStartingCapture = true
        defer { isStartingCapture = false }

        await configureIfNeeded()

        let authorizationStatus = await ensureLocationAuthorization()
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            statusNote = "Allow location access on Apple Watch to add passive watch route data."
            return
        }

        autoCaptureEnabled = true
        UserDefaults.standard.set(true, forKey: Self.autoCaptureEnabledKey)
        isCapturing = true
        captureSummary = "Best-effort passive capture"
        statusNote = "Capturing watch location, pedometer, and motion while the system keeps the app active during movement."
        locationManager.startUpdatingLocation()
        startMotionFeedsIfNeeded()
    }

    func stopCapture() {
        guard isCapturing else {
            return
        }

        autoCaptureEnabled = false
        UserDefaults.standard.set(false, forKey: Self.autoCaptureEnabledKey)
        isCapturing = false
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        motionActivityManager.stopActivityUpdates()
        captureSummary = "Idle"
        statusNote = "Capture stopped. Pending observations stay queued until transferred."
        flushPendingObservations(
            forceFileTransfer: true,
            trigger: "stop"
        )
    }

    func flushPendingObservations(
        forceFileTransfer: Bool,
        trigger: String = "manual"
    ) {
        guard pendingObservations.isEmpty == false else {
            return
        }

        flushAttemptCount += 1
        guard session.activationState == .activated else {
            deferredFlushCount += 1
            lastFlushSummary = "\(Date.now.formatted(date: .omitted, time: .shortened)) • deferred • \(trigger)"
            statusNote = "Queued watch observations are waiting for Watch Connectivity activation."
            refreshSessionState()
            return
        }

        let envelope = WatchObservationTransferEnvelope(observations: pendingObservations)
        guard let payloadData = try? encoder.encode(envelope) else {
            statusNote = "Blackbox could not encode the watch observation batch."
            return
        }

        let deliveryMode = "file"
        let fileURL = makeTransferFile(for: payloadData)
        session.transferFile(fileURL, metadata: [
            WatchObservationTransferEnvelope.payloadKey: envelope.observations.count
        ])

        totalTransferredObservationCount += pendingObservations.count
        lastTransferSummary = "\(Date.now.formatted(date: .omitted, time: .shortened)) • \(pendingObservations.count) observations • \(deliveryMode)"
        lastFlushSummary = "\(Date.now.formatted(date: .omitted, time: .shortened)) • sent • \(trigger)"
        pendingObservations.removeAll(keepingCapacity: true)
        pendingObservationCount = 0
        lastFlushDate = .now
        refreshSessionState()
    }

    private func ensureLocationAuthorization() async -> CLAuthorizationStatus {
        let status = locationManager.authorizationStatus
        guard status == .notDetermined else {
            return status
        }

        return await withCheckedContinuation { continuation in
            locationAuthorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func resumeLocationAuthorization(_ status: CLAuthorizationStatus) {
        guard let locationAuthorizationContinuation else {
            return
        }

        self.locationAuthorizationContinuation = nil
        locationAuthorizationContinuation.resume(returning: status)
    }

    private func restorePassiveCaptureIfNeeded() async {
        if isCapturing == false {
            await startCapture()
        }
    }

    private func startMotionFeedsIfNeeded() {
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: .now) { [weak self] data, error in
                guard let self else {
                    return
                }

                Task { @MainActor in
                    if let error {
                        self.statusNote = "Watch pedometer error: \(error.localizedDescription)"
                        return
                    }

                    guard let data else {
                        return
                    }

                    self.recordPedometerData(data)
                }
            }
        }

        if CMMotionActivityManager.isActivityAvailable() {
            motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self, let activity else {
                    return
                }

                Task { @MainActor in
                    self.recordMotionActivity(activity)
                }
            }
        }
    }

    private func recordLocations(_ locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy >= 0 {
            appendObservation(
                timestamp: location.timestamp,
                sourceType: .location,
                payload: locationPayload(for: location),
                qualityHint: horizontalAccuracyHint(for: location)
            )
            locationObservationCount += 1
        }
    }

    private func recordPedometerData(_ data: CMPedometerData) {
        appendObservation(
            timestamp: data.endDate,
            sourceType: .pedometer,
            payload: pedometerPayload(for: data),
            qualityHint: nil
        )
        pedometerObservationCount += 1
    }

    private func recordMotionActivity(_ activity: CMMotionActivity) {
        appendObservation(
            timestamp: activity.startDate,
            sourceType: .motion,
            payload: motionPayload(for: activity),
            qualityHint: confidenceHint(for: activity.confidence)
        )
        motionObservationCount += 1
    }

    private func handleLocationFailure(_ error: Error) {
        if let clError = error as? CLError, clError.code == .locationUnknown {
            if isCapturing {
                statusNote = "Waiting for a watch location fix."
            }
            return
        }

        statusNote = "Watch location error: \(error.localizedDescription)"
    }

    private func appendObservation(
        timestamp: Date,
        sourceType: ObservationSourceType,
        payload: String,
        qualityHint: String?
    ) {
        pendingObservations.append(
            WatchObservationTransfer(
                timestamp: timestamp,
                sourceType: sourceType,
                payload: payload,
                qualityHint: qualityHint,
                ingestedAt: .now
            )
        )
        pendingObservationCount = pendingObservations.count
        totalQueuedObservationCount += 1

        let shouldFlushByCount = pendingObservations.count >= 25
        let shouldFlushByAge: Bool
        let trigger: String
        if let lastFlushDate {
            shouldFlushByAge = Date.now.timeIntervalSince(lastFlushDate) >= 30
            trigger = shouldFlushByCount ? "count>=25" : "age>=30s"
        } else {
            shouldFlushByAge = pendingObservations.count >= 10
            trigger = shouldFlushByCount ? "count>=25" : "startup>=10"
        }

        if shouldFlushByCount || shouldFlushByAge {
            flushPendingObservations(
                forceFileTransfer: true,
                trigger: trigger
            )
        }
    }

    private func refreshSessionState() {
        guard WCSession.isSupported() else {
            sessionSummary = "Unsupported"
            sessionImageName = "applewatch.slash"
            statusNote = "This Apple Watch cannot talk to the paired iPhone."
            return
        }

        switch session.activationState {
        case .activated:
            if session.isReachable {
                sessionSummary = "Connected"
                sessionImageName = "applewatch.radiowaves.left.and.right"
            } else {
                sessionSummary = "Background Queue"
                sessionImageName = "arrow.triangle.2.circlepath"
            }
        case .inactive:
            sessionSummary = "Inactive"
            sessionImageName = "applewatch.slash"
        case .notActivated:
            sessionSummary = "Activating"
            sessionImageName = "applewatch"
        @unknown default:
            sessionSummary = "Unknown"
            sessionImageName = "applewatch"
        }
    }

    private func locationPayload(for location: CLLocation) -> String {
        [
            "lat=\(location.coordinate.latitude)",
            "lon=\(location.coordinate.longitude)",
            "alt=\(location.altitude)",
            "speed=\(location.speed)",
            "course=\(location.course)",
            "hAcc=\(location.horizontalAccuracy)",
            "vAcc=\(location.verticalAccuracy)",
            "origin=live",
        ]
        .joined(separator: ";")
    }

    private func horizontalAccuracyHint(for location: CLLocation) -> String? {
        if location.horizontalAccuracy > 100 {
            return "degraded-horizontal-accuracy"
        }

        return nil
    }

    private func pedometerPayload(for data: CMPedometerData) -> String {
        var components = [
            "start=\(data.startDate.timeIntervalSince1970)",
            "end=\(data.endDate.timeIntervalSince1970)",
            "steps=\(data.numberOfSteps)",
        ]

        if let distance = data.distance {
            components.append("distance=\(distance)")
        }

        if let floorsAscended = data.floorsAscended {
            components.append("floorsAscended=\(floorsAscended)")
        }

        if let floorsDescended = data.floorsDescended {
            components.append("floorsDescended=\(floorsDescended)")
        }

        if let currentPace = data.currentPace {
            components.append("currentPace=\(currentPace)")
        }

        if let currentCadence = data.currentCadence {
            components.append("currentCadence=\(currentCadence)")
        }

        components.append("origin=live")
        return components.joined(separator: ";")
    }

    private func motionPayload(for activity: CMMotionActivity) -> String {
        [
            "stationary=\(activity.stationary)",
            "walking=\(activity.walking)",
            "running=\(activity.running)",
            "cycling=\(activity.cycling)",
            "automotive=\(activity.automotive)",
            "unknown=\(activity.unknown)",
            "origin=live",
        ]
        .joined(separator: ";")
    }

    private func confidenceHint(for confidence: CMMotionActivityConfidence) -> String? {
        switch confidence {
        case .low:
            return "low-confidence"
        case .medium:
            return "medium-confidence"
        case .high:
            return nil
        @unknown default:
            return "unknown-confidence"
        }
    }

    private func makeTransferFile(for payloadData: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-observation-batch-\(UUID().uuidString)")
            .appendingPathExtension("json")
        try? payloadData.write(to: url, options: .atomic)
        return url
    }
}

private final class WatchCaptureDelegateProxy: NSObject, WCSessionDelegate, CLLocationManagerDelegate {
    var onActivationChange: ((WCSessionActivationState, Error?) -> Void)?
    var onReachabilityChange: (() -> Void)?
    var onLocationAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocations: (([CLLocation]) -> Void)?
    var onLocationFailure: ((Error) -> Void)?

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        onActivationChange?(activationState, error)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        onReachabilityChange?()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onLocationAuthorizationChange?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        onLocations?(locations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        onLocationFailure?(error)
    }
}
