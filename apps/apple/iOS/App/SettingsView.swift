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

    var body: some View {
        NavigationStack {
            List {
                CaptureStatusSection(
                    statuses: captureReadiness.statuses,
                    onRefresh: onRefreshCaptureReadiness,
                    onRequestLocation: onRequestLocationAuthorization
                )

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
