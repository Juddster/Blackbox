import SwiftUI

struct SettingsView: View {
    let captureReadiness: CaptureReadinessStore
    let captureControl: CaptureControlStore
    let onRefreshCaptureReadiness: () -> Void
    let onRequestLocationAuthorization: () async -> Void
    let onStartLocation: () async -> Void
    let onStopLocation: () -> Void
    let onStartMotion: () async -> Void
    let onStopMotion: () -> Void
    let onStartPedometer: () async -> Void
    let onStopPedometer: () -> Void
    let watchConnectivity: WatchConnectivityStore

    var body: some View {
        NavigationStack {
            List {
                CaptureStatusSection(
                    statuses: captureReadiness.statuses,
                    onRefresh: onRefreshCaptureReadiness,
                    onRequestLocation: onRequestLocationAuthorization
                )

                Section("Watch") {
                    LabeledContent("Connection", value: watchConnectivity.connectionSummary)
                    LabeledContent("Watch App", value: watchConnectivity.installationSummary)

                    if let lastReceivedSummary = watchConnectivity.lastReceivedSummary {
                        LabeledContent("Last Intake", value: lastReceivedSummary)
                    }

                    if let lastReceivedBreakdownSummary = watchConnectivity.lastReceivedBreakdownSummary {
                        LabeledContent("Last Batch", value: lastReceivedBreakdownSummary)
                    }

                    LabeledContent("Last Transport", value: watchConnectivity.lastReceiveTransport)
                    LabeledContent("Intake Totals", value: watchConnectivity.diagnosticsSummary)

                    if let statusNote = watchConnectivity.statusNote {
                        Text(statusNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                CaptureControlSection(
                    isLocationCapturing: captureControl.isLocationCapturing,
                    isMotionCapturing: captureControl.isMotionCapturing,
                    isPedometerCapturing: captureControl.isPedometerCapturing,
                    statusMessage: captureControl.statusMessage,
                    gapNotice: captureControl.gapNotice,
                    onStartLocation: onStartLocation,
                    onStopLocation: onStopLocation,
                    onStartMotion: onStartMotion,
                    onStopMotion: onStopMotion,
                    onStartPedometer: onStartPedometer,
                    onStopPedometer: onStopPedometer
                )
            }
            .navigationTitle("Settings")
        }
    }
}
