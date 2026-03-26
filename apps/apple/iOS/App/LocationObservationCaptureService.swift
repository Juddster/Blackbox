@preconcurrency import CoreLocation
import Foundation

@MainActor
final class LocationObservationCaptureService: ObservationCapturing {
    private let recorder: ObservationIngesting
    private let locationManager: CLLocationManager
    private let delegateProxy: LocationObservationDelegateProxy
    private let supportsBackgroundLocation: Bool

    private(set) var isCapturing: Bool = false
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

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
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
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
        let inputs = locations.map { location in
            ObservationInput(
                timestamp: location.timestamp,
                sourceDevice: .iPhone,
                sourceType: .location,
                payload: locationPayload(for: location),
                qualityHint: horizontalAccuracyHint(for: location)
            )
        }

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

    private static func supportsBackgroundLocationUpdates() -> Bool {
        guard let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else {
            return false
        }

        return backgroundModes.contains("location")
    }
}
