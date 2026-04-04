import SwiftUI

@main
struct BlackboxWatchApp: App {
    @State private var captureStore = WatchCaptureStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView(captureStore: captureStore)
        }
    }
}
