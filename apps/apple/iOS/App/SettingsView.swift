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
    let healthBackfill: HealthBackfillStore
    let onRequestHealthAuthorization: () async -> Void
    let onBackfillRecentWatchHealth: () async -> Void

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

                    if let latestWatchMetadataSummary = watchConnectivity.latestWatchMetadataSummary {
                        LabeledContent("Watch Sender", value: latestWatchMetadataSummary)
                    }

                    LabeledContent("Last Transport", value: watchConnectivity.lastReceiveTransport)
                    LabeledContent("Intake Totals", value: watchConnectivity.diagnosticsSummary)

                    if let statusNote = watchConnectivity.statusNote {
                        Text(statusNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Health Backfill") {
                    LabeledContent("Access", value: healthBackfill.authorizationSummary)

                    Button("Request Health Access") {
                        Task {
                            await onRequestHealthAuthorization()
                        }
                    }

                    Button("Backfill Recent Watch Activity") {
                        Task {
                            await onBackfillRecentWatchHealth()
                        }
                    }
                    .disabled(healthBackfill.hasRequestedAuthorization == false)

                    if let lastBackfillSummary = healthBackfill.lastBackfillSummary {
                        LabeledContent("Last Import", value: lastBackfillSummary)
                    }

                    if let lastBreakdownSummary = healthBackfill.lastBreakdownSummary {
                        LabeledContent("Last Batch", value: lastBreakdownSummary)
                    }

                    if let statusNote = healthBackfill.statusNote {
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
