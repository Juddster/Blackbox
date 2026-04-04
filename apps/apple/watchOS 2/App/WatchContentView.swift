import SwiftUI

struct WatchContentView: View {
    @State var captureStore: WatchCaptureStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                statusSection
                controlsSection
                countsSection
                pendingSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .task {
            await captureStore.configureIfNeeded()
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Blackbox Watch")
                .font(.headline)
            Label(captureStore.sessionSummary, systemImage: captureStore.sessionImageName)
                .font(.footnote)
            if let note = captureStore.statusNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(captureStore.isCapturing ? "Stop Capture" : "Start Capture") {
                Task {
                    if captureStore.isCapturing {
                        captureStore.stopCapture()
                    } else {
                        await captureStore.startCapture()
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Send Pending Batch") {
                captureStore.flushPendingObservations(forceFileTransfer: false)
            }
            .buttonStyle(.bordered)
            .disabled(captureStore.pendingObservationCount == 0)
        }
    }

    private var countsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            metricRow(title: "Queued", value: "\(captureStore.pendingObservationCount)")
            metricRow(title: "Sent", value: "\(captureStore.totalTransferredObservationCount)")
            metricRow(title: "Locations", value: "\(captureStore.locationObservationCount)")
            metricRow(title: "Pedometer", value: "\(captureStore.pedometerObservationCount)")
            metricRow(title: "Motion", value: "\(captureStore.motionObservationCount)")
        }
        .font(.footnote)
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Transfer")
                .font(.footnote.weight(.semibold))
            Text(captureStore.lastTransferSummary ?? "Nothing transferred yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }
}

#Preview {
    WatchContentView(captureStore: WatchCaptureStore())
}
