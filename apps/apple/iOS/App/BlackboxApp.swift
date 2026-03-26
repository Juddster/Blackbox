import SwiftData
import SwiftUI

@main
struct BlackboxApp: App {
    private let modelContainer = ModelContainer.blackbox

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? AppBootstrap.seedIfNeeded(modelContext: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
