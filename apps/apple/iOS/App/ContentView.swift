import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var captureReadiness = CaptureReadinessStore()
    @State private var captureControl = CaptureControlStore()
    @State private var syncActivity = SyncActivityStore()
    @State private var presentedResumeReport: CaptureResumeReport?

    var body: some View {
        TabView {
            TimelineView(syncActivity: syncActivity)
                .tabItem {
                    Label("Activity", systemImage: "figure.walk.motion")
                }

            SettingsView(
                captureReadiness: captureReadiness,
                captureControl: captureControl,
                onRefreshCaptureReadiness: refreshCaptureReadiness,
                onRequestLocationAuthorization: requestLocationAuthorization,
                onStartLocation: startLocationCapture,
                onStopLocation: stopLocationCapture,
                onStartMotion: startMotionCapture,
                onStopMotion: stopMotionCapture,
                onStartPedometer: startPedometerCapture,
                onStopPedometer: stopPedometerCapture
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }

            DataView(syncActivity: syncActivity)
                .tabItem {
                    Label("Data", systemImage: "tray.full")
                }
        }
        .task {
            configureCapture()
            presentedResumeReport = await captureControl.handleDidBecomeActive()
            await resumeCaptureIfNeeded()
            backfillSegmentMetrics()
            refreshCaptureReadiness()
            refreshSyncActivity()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    presentedResumeReport = await captureControl.handleDidBecomeActive()
                    await resumeCaptureIfNeeded()
                    backfillSegmentMetrics()
                    refreshSyncActivity()
                }
            } else if scenePhase == .background {
                captureControl.handleDidEnterBackground()
            }
        }
        .alert(
            presentedResumeReport?.title ?? "Capture Summary",
            isPresented: Binding(
                get: { presentedResumeReport != nil },
                set: { isPresented in
                    if isPresented == false {
                        presentedResumeReport = nil
                    }
                }
            ),
            actions: {
                Button("OK") {
                    presentedResumeReport = nil
                }
            },
            message: {
                Text(presentedResumeReport?.message ?? "")
            }
        )
    }

    private func configureCapture() {
        captureControl.configure(modelContext: modelContext)
    }

    private func resumeCaptureIfNeeded() async {
        await captureControl.resumeIfNeeded()
        refreshCaptureReadiness()
    }

    private func refreshCaptureReadiness() {
        captureReadiness.refresh()
    }

    private func requestLocationAuthorization() async {
        await captureReadiness.requestLocationAuthorization()
    }

    private func startLocationCapture() async {
        await captureControl.startLocationCapture()
        refreshCaptureReadiness()
    }

    private func stopLocationCapture() {
        captureControl.stopLocationCapture()
    }

    private func startMotionCapture() async {
        await captureControl.startMotionCapture()
        refreshCaptureReadiness()
    }

    private func stopMotionCapture() {
        captureControl.stopMotionCapture()
    }

    private func startPedometerCapture() async {
        await captureControl.startPedometerCapture()
        refreshCaptureReadiness()
    }

    private func stopPedometerCapture() {
        captureControl.stopPedometerCapture()
    }

    private func refreshSyncActivity() {
        syncActivity.refresh(using: modelContext)
    }

    private func backfillSegmentMetrics() {
        let backfiller = LocalSegmentMetricBackfiller(modelContext: modelContext)
        try? backfiller.backfillMissingDistanceMetrics()
    }
}

#Preview {
    ContentView()
        .modelContainer(ModelContainer.blackbox)
}
