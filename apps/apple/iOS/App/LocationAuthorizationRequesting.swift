import CoreLocation
import Foundation

@MainActor
protocol LocationAuthorizationRequesting {
    func requestBackgroundAuthorization() async -> CLAuthorizationStatus
}
