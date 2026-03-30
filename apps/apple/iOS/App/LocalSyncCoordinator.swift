import Foundation
import SwiftData

@MainActor
final class LocalSyncCoordinator {
    private let client: SegmentSyncing
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        self.client = DemoSegmentSyncClient()
    }

    init(client: SegmentSyncing) {
        self.client = client
    }

    func pendingEnvelopes(modelContext: ModelContext) throws -> [SegmentEnvelope] {
        try envelopes(
            modelContext: modelContext,
            matching: .pendingUpload
        )
    }

    func conflictedEnvelopes(modelContext: ModelContext) throws -> [SegmentEnvelope] {
        try envelopes(
            modelContext: modelContext,
            matching: .conflicted
        )
    }

    func pushPendingEnvelopes(modelContext: ModelContext) async throws -> Int {
        let records = try pendingRecords(modelContext: modelContext)
        let envelopes = try SyncEnvelopeProjection.makeEnvelopes(from: records)
        let outcome = try await client.push(envelopes)
        try apply(outcome: outcome, to: records, modelContext: modelContext)
        return outcome.acceptedCount
    }

    func pullEnvelopes(modelContext: ModelContext) async throws -> Int {
        let envelopes = try await client.pull()
        let applier = LocalSegmentEnvelopeApplier(modelContext: modelContext)
        return try applier.apply(envelopes)
    }

    func applyStoredServerEnvelope(
        for segmentID: UUID,
        modelContext: ModelContext
    ) throws {
        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        guard
            let record = records.first(where: { $0.id == segmentID }),
            let syncState = record.syncState,
            let data = syncState.pendingServerEnvelopeData
        else {
            return
        }

        let envelope = try decoder.decode(SegmentEnvelope.self, from: data)
        if envelope.sync.isDeleted == false {
            LocalDeletedSegmentStore.remove(segmentID)
        }
        let applier = LocalSegmentEnvelopeApplier(modelContext: modelContext)
        _ = try applier.apply([envelope])
    }

    func requeueLocalVersion(
        for segmentID: UUID,
        modelContext: ModelContext
    ) throws {
        guard
            let record = try record(for: segmentID, modelContext: modelContext),
            let syncState = record.syncState,
            let data = syncState.pendingServerEnvelopeData
        else {
            return
        }

        let envelope = try decoder.decode(SegmentEnvelope.self, from: data)
        guard envelope.sync.isDeleted == false else {
            return
        }
        syncState.syncVersion = envelope.sync.syncVersion
        syncState.disposition = .pendingUpload
        syncState.lastSyncError = nil
        syncState.pendingServerEnvelopeData = nil
        syncState.lastModifiedAt = .now
        try modelContext.save()
    }

    func restoreDeletedSegment(
        for segmentID: UUID,
        modelContext: ModelContext
    ) throws {
        guard
            let record = try record(for: segmentID, modelContext: modelContext),
            let syncState = record.syncState,
            let data = syncState.pendingServerEnvelopeData
        else {
            return
        }

        let envelope = try decoder.decode(SegmentEnvelope.self, from: data)
        guard envelope.sync.isDeleted else {
            return
        }

        record.lifecycleState = .unsettled
        syncState.syncVersion = envelope.sync.syncVersion
        syncState.isDeleted = false
        syncState.disposition = .pendingUpload
        syncState.lastSyncError = nil
        syncState.pendingServerEnvelopeData = nil
        syncState.lastModifiedAt = .now
        try modelContext.save()
        LocalDeletedSegmentStore.remove(segmentID)
    }

    private func envelopes(
        modelContext: ModelContext,
        matching disposition: SyncDisposition
    ) throws -> [SegmentEnvelope] {
        let matchingRecords = try records(modelContext: modelContext, matching: disposition)
        return try SyncEnvelopeProjection.makeEnvelopes(from: matchingRecords)
    }

    private func pendingRecords(modelContext: ModelContext) throws -> [SegmentRecord] {
        try records(modelContext: modelContext, matching: .pendingUpload)
    }

    private func records(
        modelContext: ModelContext,
        matching disposition: SyncDisposition
    ) throws -> [SegmentRecord] {
        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        return records.filter {
            $0.syncState?.disposition == disposition
        }
    }

    private func record(
        for segmentID: UUID,
        modelContext: ModelContext
    ) throws -> SegmentRecord? {
        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        return records.first(where: { $0.id == segmentID })
    }

    private func apply(
        outcome: SegmentPushOutcome,
        to records: [SegmentRecord],
        modelContext: ModelContext
    ) throws {
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        for accepted in outcome.accepted {
            guard let record = recordsByID[accepted.segmentID] else {
                continue
            }

            if record.lifecycleState == .deleted || record.syncState?.isDeleted == true {
                LocalDeletedSegmentStore.markDeleted(accepted.segmentID)
                modelContext.delete(record)
                continue
            }

            if let syncState = record.syncState {
                syncState.syncVersion = accepted.syncVersion
                syncState.lastModifiedAt = accepted.updatedAt
                syncState.disposition = .synced
                syncState.lastSyncError = nil
                syncState.pendingServerEnvelopeData = nil
                LocalDeletedSegmentStore.remove(accepted.segmentID)
            }
        }

        for conflict in outcome.conflicts {
            guard let record = recordsByID[conflict.segmentID] else {
                continue
            }

            if let syncState = record.syncState {
                syncState.disposition = .conflicted
                syncState.lastSyncError = conflict.reason
                syncState.pendingServerEnvelopeData = try conflict.serverEnvelope.map(encoder.encode)
            }
        }

        try modelContext.save()
    }
}

enum LocalDeletedSegmentStore {
    private static let key = "capture.locally-deleted-segment-ids"

    static func contains(_ segmentID: UUID, defaults: UserDefaults = .standard) -> Bool {
        storedIDs(defaults: defaults).contains(segmentID.uuidString)
    }

    static func markDeleted(_ segmentID: UUID, defaults: UserDefaults = .standard) {
        var ids = storedIDs(defaults: defaults)
        ids.insert(segmentID.uuidString)
        defaults.set(Array(ids).sorted(), forKey: key)
    }

    static func remove(_ segmentID: UUID, defaults: UserDefaults = .standard) {
        var ids = storedIDs(defaults: defaults)
        ids.remove(segmentID.uuidString)
        defaults.set(Array(ids).sorted(), forKey: key)
    }

    private static func storedIDs(defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }
}
