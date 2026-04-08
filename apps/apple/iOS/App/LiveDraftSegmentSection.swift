import SwiftUI

struct LiveDraftSegmentSection: View {
    @Binding var isExpanded: Bool
    let draft: LiveDraftSegmentSnapshot?
    let statusMessage: String?
    let onPersistDraft: () async -> Void

    var body: some View {
        Section("Current Inference") {
            DisclosureGroup(isExpanded: $isExpanded) {
                if let draft {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: draft.activityClass.systemImage)
                                .font(.title3)
                                .foregroundStyle(activityColor)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(draft.title)
                                    .font(.headline)

                                Text(draft.activityClass.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(draft.confidence, format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Label(
                                "\(draft.startTime.formatted(date: .omitted, time: .shortened)) - \(draft.endTime.formatted(date: .omitted, time: .shortened))",
                                systemImage: "clock"
                            )
                            Spacer()
                            Label(
                                Duration.seconds(draft.endTime.timeIntervalSince(draft.startTime))
                                    .formatted(.units(allowed: [.minutes], width: .abbreviated)),
                                systemImage: "timer"
                            )
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if let distanceMeters = draft.distanceMeters {
                            Text(
                                Measurement(value: distanceMeters, unit: UnitLength.meters)
                                    .formatted(.measurement(width: .abbreviated, usage: .road))
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        Text(sourceSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if draft.needsReview {
                            Label("Low-confidence draft", systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        Button("Add Or Update Timeline Segment") {
                            Task {
                                await onPersistDraft()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    Text("No current inferred activity yet. Expand this card after fresh observations arrive to recalculate it.")
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text(isExpanded ? "Hide Current Inference" : "Show Current Inference")
                    .font(.subheadline.weight(.medium))
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sourceSummary: String {
        guard let draft else {
            return ""
        }

        let names = draft.supportingSources.map {
            switch $0 {
            case .location:
                "location"
            case .motion:
                "motion"
            case .pedometer:
                "pedometer"
            case .heartRate:
                "heart rate"
            case .deviceState:
                "device"
            case .connectivity:
                "connectivity"
            case .other:
                "other"
            }
        }

        return "Based on \(names.joined(separator: ", ")) observations from the last 20 minutes."
    }

    private var activityColor: Color {
        guard let draft else {
            return Color.secondary
        }

        switch draft.activityClass {
        case .stationary:
            return Color.gray
        case .walking:
            return Color.green
        case .running:
            return Color.orange
        case .cycling:
            return Color.mint
        case .hiking:
            return Color.brown
        case .vehicle:
            return Color.blue
        case .flight:
            return Color.indigo
        case .waterActivity:
            return Color.cyan
        case .unknown:
            return Color.secondary
        }
    }
}
