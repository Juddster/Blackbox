import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SyncActivityStore {
    var pendingCount: Int = 0
    var conflictedCount: Int = 0
    var conflicts = [SyncConflictSnapshot]()
    var isSyncing = false
    var lastPushMessage: String?
    var lastSyncAt: Date?

    private let coordinator: LocalSyncCoordinator

    init() {
        self.coordinator = LocalSyncCoordinator()
    }

    init(coordinator: LocalSyncCoordinator) {
        self.coordinator = coordinator
    }

    func refresh(using modelContext: ModelContext) {
        do {
            let pendingStates = try modelContext.fetch(
                FetchDescriptor<SegmentSyncStateRecord>(
                    predicate: #Predicate { state in
                        state.disposition.rawValue == "pendingUpload"
                    }
                )
            )
            let conflictedStates = try modelContext.fetch(
                FetchDescriptor<SegmentSyncStateRecord>(
                    predicate: #Predicate { state in
                        state.disposition.rawValue == "conflicted"
                    }
                )
            )

            pendingCount = pendingStates.count
            conflictedCount = conflictedStates.count
            conflicts = conflictedStates.compactMap { state in
                guard let segment = state.segment else {
                    return nil
                }

                return SyncConflictSnapshot(
                    id: segment.id,
                    title: segment.title,
                    message: conflictMessage(for: state.lastSyncError)
                )
            }
        } catch {
            lastPushMessage = "Failed to load sync state."
        }
    }

    func pushPending(using modelContext: ModelContext) async {
        guard isSyncing == false else {
            return
        }

        isSyncing = true
        lastPushMessage = "Running sync pass..."

        do {
            let pushedCount = try await coordinator.pushPendingEnvelopes(modelContext: modelContext)
            let pulledCount = try await coordinator.pullEnvelopes(modelContext: modelContext)
            lastSyncAt = .now
            refresh(using: modelContext)
            lastPushMessage = syncMessage(
                pushedCount: pushedCount,
                pulledCount: pulledCount
            )
        } catch {
            lastPushMessage = "Sync preparation failed."
        }

        isSyncing = false
    }

    private func syncMessage(pushedCount: Int, pulledCount: Int) -> String {
        switch (pushedCount, pulledCount, conflictedCount) {
        case (0, 0, let conflictedCount) where conflictedCount > 0:
            return "Sync pass found conflicts that need review."
        case (0, 0, _):
            return "No sync changes were exchanged."
        case (_, 0, let conflictedCount) where conflictedCount > 0:
            return "Accepted \(pushedCount) pushes and left \(conflictedCount) conflicts to resolve."
        case (_, 0, _):
            return "Accepted \(pushedCount) segment envelopes in the local sync pass."
        case (0, _, let conflictedCount) where conflictedCount > 0:
            return "Applied \(pulledCount) pulled envelopes and left \(conflictedCount) conflicts."
        case (0, _, _):
            return "Applied \(pulledCount) pulled segment envelopes locally."
        default:
            return "Accepted \(pushedCount) pushed and applied \(pulledCount) pulled segment envelopes."
        }
    }

    private func conflictMessage(for error: String?) -> String {
        switch error {
        case "versionMismatch":
            return "Server has a newer version."
        case "deletedOnServer":
            return "Server deleted this segment."
        case let error?:
            return error
        case nil:
            return "Sync conflict needs review."
        }
    }
}
