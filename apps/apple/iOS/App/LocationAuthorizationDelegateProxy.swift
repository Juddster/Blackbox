@preconcurrency import CoreLocation
import Foundation

final class LocationAuthorizationDelegateProxy: NSObject, CLLocationManagerDelegate {
    var onAuthorizationChange: (@MainActor (CLAuthorizationStatus) -> Void)?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            onAuthorizationChange?(status)
        }
    }
}
