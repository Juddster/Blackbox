import SwiftUI

final class BlackboxWatchExtensionDelegate: NSObject, WKExtensionDelegate {
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in
            await WatchCaptureStore.shared.recoverActiveWorkoutSessionIfNeeded()
        }
    }
}

@main
struct BlackboxWatchApp: App {
    @WKExtensionDelegateAdaptor(BlackboxWatchExtensionDelegate.self) private var extensionDelegate
    @State private var captureStore = WatchCaptureStore.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView(captureStore: captureStore)
        }
    }
}
