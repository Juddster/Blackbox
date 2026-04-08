import SwiftData
import SwiftUI

@main
struct BlackboxApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var modelContainerErrorMessage: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer {
                    ContentView()
                        .modelContainer(modelContainer)
                } else if let modelContainerErrorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Blackbox could not open its local store.")
                            .font(.headline)
                        Text(modelContainerErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Opening Blackbox")
                            .font(.headline)
                    }
                    .task {
                        await loadModelContainerIfNeeded()
                    }
                }
            }
        }
    }

    private func loadModelContainerIfNeeded() async {
        guard modelContainer == nil, modelContainerErrorMessage == nil else {
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        print("[ModelContainer] Starting container bootstrap.")

        do {
            let container = try await Task.detached(priority: .userInitiated) {
                let creationStartTime = CFAbsoluteTimeGetCurrent()
                let container = try ModelContainer.makeBlackbox()
                let creationElapsed = CFAbsoluteTimeGetCurrent() - creationStartTime
                print("[ModelContainer] ModelContainer.makeBlackbox finished in \(String(format: "%.3f", creationElapsed))s.")
                return container
            }.value

            let totalElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("[ModelContainer] Container bootstrap completed in \(String(format: "%.3f", totalElapsed))s.")
            modelContainer = container
        } catch {
            let totalElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("[ModelContainer] Container bootstrap failed in \(String(format: "%.3f", totalElapsed))s: \(error)")
            modelContainerErrorMessage = error.localizedDescription
        }
    }
}
