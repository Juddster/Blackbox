import SwiftData
import SwiftUI

struct DataView: View {
    @Environment(\.modelContext) private var modelContext
    let syncActivity: SyncActivityStore

    @Query(
        sort: [
            SortDescriptor(\ObservationRecord.timestamp, order: .reverse),
        ],
        animation: .snappy
    )
    private var observations: [ObservationRecord]

    var body: some View {
        NavigationStack {
            List {
                SyncStatusSection(
                    pendingCount: syncActivity.pendingCount,
                    conflictedCount: syncActivity.conflictedCount,
                    conflicts: syncActivity.conflicts,
                    isSyncing: syncActivity.isSyncing,
                    lastPushMessage: syncActivity.lastPushMessage,
                    lastSyncAt: syncActivity.lastSyncAt,
                    onPushPending: pushPendingSync
                )

                RecentObservationsSection(observations: ObservationProjection.recent(from: observations))
            }
            .navigationTitle("Data")
        }
    }

    private func pushPendingSync() async {
        await syncActivity.pushPending(using: modelContext)
    }
}
