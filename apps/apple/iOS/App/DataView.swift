import SwiftData
import SwiftUI

struct DataView: View {
    @Environment(\.modelContext) private var modelContext
    let syncActivity: SyncActivityStore

    @State private var recentObservations = [ObservationSnapshot]()

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

                RecentObservationsSection(observations: recentObservations)
            }
            .navigationTitle("Data")
        }
        .task {
            refreshRecentObservations()
        }
    }

    private func pushPendingSync() async {
        await syncActivity.pushPending(using: modelContext)
        refreshRecentObservations()
    }

    private func refreshRecentObservations() {
        var descriptor = FetchDescriptor<ObservationRecord>(
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        let observations = (try? modelContext.fetch(descriptor)) ?? []
        recentObservations = ObservationProjection.recent(from: observations)
    }
}
