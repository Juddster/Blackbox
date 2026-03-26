import SwiftUI

struct SyncStatusSection: View {
    let pendingCount: Int
    let conflictedCount: Int
    let conflicts: [SyncConflictSnapshot]
    let isSyncing: Bool
    let lastPushMessage: String?
    let lastSyncAt: Date?
    let onPushPending: () async -> Void

    var body: some View {
        Section("Sync") {
            LabeledContent("Pending", value: "\(pendingCount)")
            LabeledContent("Conflicted", value: "\(conflictedCount)")

            if let lastSyncAt {
                LabeledContent("Last Sync Pass", value: lastSyncAt.formatted(date: .omitted, time: .shortened))
            }

            Button(isSyncing ? "Syncing..." : "Run Sync Pass") {
                Task {
                    await onPushPending()
                }
            }
            .disabled(isSyncing)

            if conflicts.isEmpty == false {
                ForEach(conflicts.prefix(3)) { conflict in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conflict.title)
                            .font(.subheadline.weight(.medium))
                        Text(conflict.message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 2)
                }
            }

            if let lastPushMessage {
                Text(lastPushMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
