import Foundation
import Observation

@MainActor
@Observable
final class CaptureReadinessStore {
    var statuses: [CaptureServiceStatus]

    private let locationAuthorizationController: LocationAuthorizationRequesting

    init() {
        self.locationAuthorizationController = LocationAuthorizationController()
        self.statuses = CaptureProjection.currentStatuses()
    }

    init(locationAuthorizationController: LocationAuthorizationRequesting) {
        self.locationAuthorizationController = locationAuthorizationController
        self.statuses = CaptureProjection.currentStatuses()
    }

    func refresh() {
        statuses = CaptureProjection.currentStatuses()
    }

    func requestLocationAuthorization() async {
        _ = await locationAuthorizationController.requestBackgroundAuthorization()
        refresh()
    }
}
