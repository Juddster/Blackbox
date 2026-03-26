@preconcurrency import CoreLocation
import Foundation

@MainActor
final class LocationAuthorizationController: NSObject, LocationAuthorizationRequesting {
    private let locationManager: CLLocationManager
    private let delegateProxy: LocationAuthorizationDelegateProxy
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        locationManager = CLLocationManager()
        delegateProxy = LocationAuthorizationDelegateProxy()
        super.init()
        delegateProxy.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorizationChange(status)
        }
        locationManager.delegate = delegateProxy
    }

    func requestBackgroundAuthorization() async -> CLAuthorizationStatus {
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
        guard let continuation else {
            return
        }

        self.continuation = nil
        continuation.resume(returning: status)
    }

    private func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        guard locationManager.authorizationStatus == .notDetermined else {
            return locationManager.authorizationStatus
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            locationManager.requestAlwaysAuthorization()
        }
    }
}
