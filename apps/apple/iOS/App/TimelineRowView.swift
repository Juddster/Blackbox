import SwiftUI

struct TimelineRowView: View {
    let segment: SegmentSnapshot
    let onApplyServerVersion: (() async -> Void)?
    let onKeepLocalVersion: (() async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: segment.activityClass.systemImage)
                    .font(.title3)
                    .foregroundStyle(activityColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(segment.title)
                        .font(.headline)

                    Text(segment.activityLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let visibleClassLabel = segment.visibleClassLabel {
                        Text(visibleClassLabel)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if segment.needsReview {
                    Label("Review", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                }
            }

            HStack {
                Label(timeRangeText, systemImage: "clock")
                Spacer()
                Label(durationText, systemImage: "timer")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let distanceText {
                Label(distanceText, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            syncBadge

            if let syncErrorMessage, segment.syncDisposition == .conflicted {
                Text(syncErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if segment.syncDisposition == .conflicted {
                HStack {
                    if segment.canApplyServerVersion, let onApplyServerVersion {
                        Button("Apply Server Version") {
                            Task {
                                await onApplyServerVersion()
                            }
                        }
                        .font(.caption)
                    }

                    if segment.canKeepLocalVersion, let onKeepLocalVersion {
                        Button("Keep Local Version") {
                            Task {
                                await onKeepLocalVersion()
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var activityColor: Color {
        switch segment.activityClass {
        case .stationary:
            .gray
        case .walking:
            .green
        case .running:
            .orange
        case .cycling:
            .mint
        case .hiking:
            .brown
        case .vehicle:
            .blue
        case .flight:
            .indigo
        case .waterActivity:
            .cyan
        case .unknown:
            .secondary
        }
    }

    private var timeRangeText: String {
        "\(segment.startTime.formatted(date: .omitted, time: .shortened)) - \(segment.endTime.formatted(date: .omitted, time: .shortened))"
    }

    private var durationText: String {
        Duration.seconds(segment.durationSeconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private var distanceText: String? {
        guard let meters = segment.distanceMeters else {
            return nil
        }

        return Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    @ViewBuilder
    private var syncBadge: some View {
        switch segment.syncDisposition {
        case .pendingUpload:
            Label("Pending Sync", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .conflicted:
            Label("Sync Conflict", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                .font(.caption)
                .foregroundStyle(.red)
        case .synced:
            EmptyView()
        }
    }

    private var syncErrorMessage: String? {
        guard let syncErrorMessage = segment.syncErrorMessage else {
            return nil
        }

        switch syncErrorMessage {
        case "versionMismatch":
            return "Server has a newer version of this segment."
        case "deletedOnServer":
            return "Server deleted this segment."
        default:
            return syncErrorMessage
        }
    }
}
