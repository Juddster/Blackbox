import Foundation
import SwiftData

@MainActor
struct LocalSegmentEnvelopeApplier {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func apply(_ envelopes: [SegmentEnvelope]) throws -> Int {
        guard envelopes.isEmpty == false else {
            return 0
        }

        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        for envelope in envelopes {
            let record = recordsByID[envelope.id] ?? makeRecord(from: envelope.segment)
            update(record: record, from: envelope)

            if recordsByID[envelope.id] == nil {
                modelContext.insert(record)
            }
        }

        try modelContext.save()
        return envelopes.count
    }

    private func makeRecord(from payload: SegmentPayload) -> SegmentRecord {
        SegmentRecord(
            id: payload.id,
            startTime: payload.startTime,
            endTime: payload.endTime,
            lifecycleState: payload.lifecycleState,
            originType: payload.originType,
            primaryDeviceHint: payload.primaryDeviceHint,
            createdAt: payload.createdAt,
            updatedAt: payload.updatedAt,
            title: payload.title
        )
    }

    private func update(record: SegmentRecord, from envelope: SegmentEnvelope) {
        if LocalDeletedSegmentStore.contains(envelope.id), envelope.sync.isDeleted == false {
            return
        }

        if record.syncState?.isDeleted == true, envelope.sync.isDeleted == false {
            return
        }

        record.startTime = envelope.segment.startTime
        record.endTime = envelope.segment.endTime
        record.lifecycleState = envelope.segment.lifecycleState
        record.originType = envelope.segment.originType
        record.primaryDeviceHint = envelope.segment.primaryDeviceHint
        record.createdAt = envelope.segment.createdAt
        record.updatedAt = envelope.segment.updatedAt
        record.title = envelope.segment.title

        if let interpretation = envelope.interpretation {
            if let recordInterpretation = record.interpretation {
                recordInterpretation.visibleClass = interpretation.visibleClass
                recordInterpretation.userSelectedClass = interpretation.userSelectedClass
                recordInterpretation.confidence = interpretation.confidence
                recordInterpretation.ambiguityState = interpretation.ambiguityState
                recordInterpretation.needsReview = interpretation.needsReview
                recordInterpretation.interpretationOrigin = interpretation.interpretationOrigin
                recordInterpretation.updatedAt = interpretation.updatedAt
            } else {
                record.interpretation = SegmentInterpretationRecord(
                    id: interpretation.id,
                    visibleClass: interpretation.visibleClass,
                    userSelectedClass: interpretation.userSelectedClass,
                    confidence: interpretation.confidence,
                    ambiguityState: interpretation.ambiguityState,
                    needsReview: interpretation.needsReview,
                    interpretationOrigin: interpretation.interpretationOrigin,
                    updatedAt: interpretation.updatedAt
                )
            }
        } else {
            record.interpretation = nil
        }

        if let summary = envelope.summary {
            if let recordSummary = record.summary {
                recordSummary.durationSeconds = summary.durationSeconds
                recordSummary.distanceMeters = summary.distanceMeters
                recordSummary.elevationGainMeters = summary.elevationGainMeters
                recordSummary.averageSpeedMetersPerSecond = summary.averageSpeedMetersPerSecond
                recordSummary.maxSpeedMetersPerSecond = summary.maxSpeedMetersPerSecond
                recordSummary.pauseCount = summary.pauseCount
                recordSummary.updatedAt = summary.updatedAt
            } else {
                record.summary = SegmentSummaryRecord(
                    id: summary.id,
                    durationSeconds: summary.durationSeconds,
                    distanceMeters: summary.distanceMeters,
                    elevationGainMeters: summary.elevationGainMeters,
                    averageSpeedMetersPerSecond: summary.averageSpeedMetersPerSecond,
                    maxSpeedMetersPerSecond: summary.maxSpeedMetersPerSecond,
                    pauseCount: summary.pauseCount,
                    updatedAt: summary.updatedAt
                )
            }
        } else {
            record.summary = nil
        }

        let sync = envelope.sync
        if let recordSyncState = record.syncState {
            recordSyncState.lastModifiedByDeviceID = sync.lastModifiedByDeviceID
            recordSyncState.lastModifiedAt = sync.lastModifiedAt
            recordSyncState.syncVersion = sync.syncVersion
            recordSyncState.isDeleted = sync.isDeleted
            recordSyncState.disposition = .synced
            recordSyncState.lastSyncError = nil
        } else {
            record.syncState = SegmentSyncStateRecord(
                lastModifiedByDeviceID: sync.lastModifiedByDeviceID,
                lastModifiedAt: sync.lastModifiedAt,
                syncVersion: sync.syncVersion,
                isDeleted: sync.isDeleted,
                disposition: .synced
            )
        }
    }
}
