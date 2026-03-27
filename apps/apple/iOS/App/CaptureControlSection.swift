import SwiftUI

struct CaptureControlSection: View {
    let isLocationCapturing: Bool
    let isMotionCapturing: Bool
    let isPedometerCapturing: Bool
    let statusMessage: String?
    let gapNotice: CaptureGapNotice?
    let onStartLocation: () async -> Void
    let onStopLocation: () -> Void
    let onStartMotion: () async -> Void
    let onStopMotion: () -> Void
    let onStartPedometer: () async -> Void
    let onStopPedometer: () -> Void

    var body: some View {
        Section("Capture Control") {
            captureButtonRow(
                title: "Location Capture",
                isCapturing: isLocationCapturing,
                onStart: onStartLocation,
                onStop: onStopLocation
            )

            captureButtonRow(
                title: "Motion Capture",
                isCapturing: isMotionCapturing,
                onStart: onStartMotion,
                onStop: onStopMotion
            )

            captureButtonRow(
                title: "Pedometer Capture",
                isCapturing: isPedometerCapturing,
                onStart: onStartPedometer,
                onStop: onStopPedometer
            )

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let gapNotice {
                Text(gapNotice.message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func captureButtonRow(
        title: String,
        isCapturing: Bool,
        onStart: @escaping () async -> Void,
        onStop: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()

            if isCapturing {
                Button("Stop", action: onStop)
            } else {
                Button("Start") {
                    Task {
                        await onStart()
                    }
                }
            }
        }
    }
}
