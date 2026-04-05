import SwiftUI

@main
struct BlackboxWatchApp: App {
    @State private var captureStore = WatchCaptureStore.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView(captureStore: captureStore)
        }
    }
}
