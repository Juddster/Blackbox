@preconcurrency import CoreLocation
import Foundation

@MainActor
final class LocationObservationCaptureService: ObservationCapturing {
    private enum RecordingThresholds {
        static let minimumTimeInterval: TimeInterval = 5 * 60
        static let minimumDistanceMeters: CLLocationDistance = 50
        static let significantAccuracyImprovementMeters: CLLocationAccuracy = 40
        static let significantSpeedDeltaMetersPerSecond: CLLocationSpeed = 1.5
    }

    private let recorder: ObservationIngesting
    private let locationManager: CLLocationManager
    private let delegateProxy: LocationObservationDelegateProxy
    private let supportsBackgroundLocation: Bool

    private(set) var isCapturing: Bool = false
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var lastRecordedLocation: CLLocation?

    init(recorder: ObservationIngesting) {
        self.recorder = recorder
        self.locationManager = CLLocationManager()
        self.delegateProxy = LocationObservationDelegateProxy()
        self.supportsBackgroundLocation = Self.supportsBackgroundLocationUpdates()

        delegateProxy.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorizationChange(status)
        }

        delegateProxy.onLocations = { [weak self] locations in
            try? self?.record(locations: locations)
        }

        delegateProxy.onFailure = { _ in
        }

        locationManager.delegate = delegateProxy
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = RecordingThresholds.minimumDistanceMeters
        locationManager.activityType = .otherNavigation
        locationManager.pausesLocationUpdatesAutomatically = true
        if supportsBackgroundLocation {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
        }
    }

    func start() async throws {
        let authorizationStatus = await ensureAuthorization()
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return
        }

        guard isCapturing == false else {
            return
        }

        isCapturing = true
        lastRecordedLocation = nil
        locationManager.startUpdatingLocation()
        if supportsBackgroundLocation {
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }

    func stop() {
        guard isCapturing else {
            return
        }

        isCapturing = false
        locationManager.stopUpdatingLocation()
        if supportsBackgroundLocation {
            locationManager.stopMonitoringSignificantLocationChanges()
        }
    }

    private func ensureAuthorization() async -> CLAuthorizationStatus {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            let whenInUseStatus = await requestWhenInUseAuthorization()
            guard whenInUseStatus == .authorizedWhenInUse || whenInUseStatus == .authorizedAlways else {
                return whenInUseStatus
            }
        }

        if locationManager.authorizationStatus == .authorizedWhenInUse {
            return await requestAlwaysAuthorization()
        }

        return locationManager.authorizationStatus
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        guard let authorizationContinuation else {
            return
        }

        self.authorizationContinuation = nil
        authorizationContinuation.resume(returning: status)
    }

    private func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestAlwaysAuthorization()
        }
    }

    private func record(locations: [CLLocation]) throws {
        let filteredLocations = locations.filter(shouldPersist)
        let inputs = filteredLocations.map { location in
            ObservationInput(
                timestamp: location.timestamp,
                sourceDevice: .iPhone,
                sourceType: .location,
                payload: locationPayload(for: location),
                qualityHint: horizontalAccuracyHint(for: location)
            )
        }

        guard inputs.isEmpty == false else {
            return
        }

        lastRecordedLocation = filteredLocations.last
        try recorder.record(inputs)
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
        ]
        .joined(separator: ";")
    }

    private func horizontalAccuracyHint(for location: CLLocation) -> String? {
        guard location.horizontalAccuracy >= 0 else {
            return "invalid-horizontal-accuracy"
        }

        if location.horizontalAccuracy > 100 {
            return "degraded-horizontal-accuracy"
        }

        return nil
    }

    private func shouldPersist(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0 else {
            return false
        }

        guard let lastRecordedLocation else {
            return true
        }

        let elapsedTime = location.timestamp.timeIntervalSince(lastRecordedLocation.timestamp)
        if elapsedTime >= RecordingThresholds.minimumTimeInterval {
            return true
        }

        let distance = location.distance(from: lastRecordedLocation)
        if distance >= RecordingThresholds.minimumDistanceMeters {
            return true
        }

        let previousAccuracy = lastRecordedLocation.horizontalAccuracy
        let currentAccuracy = location.horizontalAccuracy
        if currentAccuracy >= 0,
           previousAccuracy >= 0,
           previousAccuracy - currentAccuracy >= RecordingThresholds.significantAccuracyImprovementMeters {
            return true
        }

        let previousSpeed = sanitizedSpeed(lastRecordedLocation.speed)
        let currentSpeed = sanitizedSpeed(location.speed)
        if abs(previousSpeed - currentSpeed) >= RecordingThresholds.significantSpeedDeltaMetersPerSecond {
            return true
        }

        return false
    }

    private func sanitizedSpeed(_ speed: CLLocationSpeed) -> CLLocationSpeed {
        max(speed, 0)
    }

    private static func supportsBackgroundLocationUpdates() -> Bool {
        guard let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else {
            return false
        }

        return backgroundModes.contains("location")
    }
}
