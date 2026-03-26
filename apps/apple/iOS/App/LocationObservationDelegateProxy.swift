@preconcurrency import CoreLocation
import Foundation

final class LocationObservationDelegateProxy: NSObject, CLLocationManagerDelegate {
    var onAuthorizationChange: (@MainActor (CLAuthorizationStatus) -> Void)?
    var onLocations: (@MainActor ([CLLocation]) -> Void)?
    var onFailure: (@MainActor (Error) -> Void)?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            onAuthorizationChange?(status)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            onLocations?(locations)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            onFailure?(error)
        }
    }
}
