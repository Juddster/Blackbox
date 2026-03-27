import SwiftUI

struct RecentObservationsSection: View {
    let observations: [ObservationSnapshot]

    var body: some View {
        Section("Recent Real Capture") {
            if observations.isEmpty {
                Text("No real captured observations yet. Start one of the capture services and new device samples will appear here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(observations) { observation in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(observation.title, systemImage: systemImage(for: observation.sourceType))
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(observation.timestamp, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(observation.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let qualityHint = observation.qualityHint {
                            Text(qualityLabel(for: qualityHint))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func systemImage(for sourceType: ObservationSourceType) -> String {
        switch sourceType {
        case .location:
            "location"
        case .motion:
            "figure.walk"
        case .pedometer:
            "shoeprints.fill"
        case .heartRate:
            "heart"
        case .deviceState:
            "iphone"
        case .connectivity:
            "antenna.radiowaves.left.and.right"
        case .other:
            "waveform.path.ecg"
        }
    }

    private func qualityLabel(for qualityHint: String) -> String {
        qualityHint.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
