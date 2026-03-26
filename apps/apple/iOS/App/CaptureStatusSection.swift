import SwiftUI

struct CaptureStatusSection: View {
    let statuses: [CaptureServiceStatus]
    let onRefresh: () -> Void
    let onRequestLocation: () async -> Void

    var body: some View {
        Section("Capture Readiness") {
            ForEach(statuses) { status in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: status.kind.systemImage)
                        .foregroundStyle(color(for: status.authorizationState))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.kind.displayName)
                            .font(.headline)

                        Text(status.authorizationState.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let note = status.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Button("Refresh Capture Status", action: onRefresh)

            if shouldShowLocationAuthorizationButton {
                Button("Request Background Location Access") {
                    Task {
                        await onRequestLocation()
                    }
                }
            }
        }
    }

    private var shouldShowLocationAuthorizationButton: Bool {
        statuses.contains {
            $0.kind == .location && ($0.authorizationState == .notDetermined || $0.authorizationState == .authorized)
        }
    }

    private func color(for state: CaptureAuthorizationState) -> Color {
        switch state {
        case .authorized:
            .green
        case .notDetermined:
            .orange
        case .denied, .restricted, .misconfigured:
            .red
        case .unavailable, .unknown:
            .secondary
        }
    }
}
