import Foundation
import UserNotifications

@MainActor
final class BackgroundCollectionNotificationCoordinator {
    private let center: UNUserNotificationCenter
    private let requestIdentifier = "background-collection-warning"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func scheduleIfNeeded(captureIsEnabled: Bool) async {
        guard captureIsEnabled else {
            cancelPendingNotification()
            return
        }

        let settings = await center.notificationSettings()
        let authorizationStatus = settings.authorizationStatus

        if authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        let refreshedSettings = await center.notificationSettings()
        guard refreshedSettings.authorizationStatus == .authorized || refreshedSettings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Blackbox collection may stop if you close the app"
        content.body = "Blackbox can keep collecting in the background, but force-closing the app may suspend capture. Reopen it if you want collection to continue."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    func cancelPendingNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
    }
}
