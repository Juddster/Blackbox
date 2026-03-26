import Foundation

enum SyncEnvelopeProjectionError: Error {
    case missingSyncState(segmentID: UUID)
}

enum SyncEnvelopeProjection {
    static func makeEnvelope(from record: SegmentRecord) throws -> SegmentEnvelope {
        guard let syncState = record.syncState else {
            throw SyncEnvelopeProjectionError.missingSyncState(segmentID: record.id)
        }

        return SegmentEnvelope(
            segment: SegmentPayload(
                id: record.id,
                startTime: record.startTime,
                endTime: record.endTime,
                lifecycleState: record.lifecycleState,
                originType: record.originType,
                primaryDeviceHint: record.primaryDeviceHint,
                title: record.title,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            ),
            interpretation: record.interpretation.map {
                SegmentInterpretationPayload(
                    id: $0.id,
                    segmentID: record.id,
                    visibleClass: $0.visibleClass,
                    userSelectedClass: $0.userSelectedClass,
                    confidence: $0.confidence,
                    ambiguityState: $0.ambiguityState,
                    needsReview: $0.needsReview,
                    interpretationOrigin: $0.interpretationOrigin,
                    updatedAt: $0.updatedAt
                )
            },
            summary: record.summary.map {
                SegmentSummaryPayload(
                    id: $0.id,
                    segmentID: record.id,
                    durationSeconds: $0.durationSeconds,
                    distanceMeters: $0.distanceMeters,
                    elevationGainMeters: $0.elevationGainMeters,
                    averageSpeedMetersPerSecond: $0.averageSpeedMetersPerSecond,
                    maxSpeedMetersPerSecond: $0.maxSpeedMetersPerSecond,
                    pauseCount: $0.pauseCount,
                    updatedAt: $0.updatedAt
                )
            },
            sync: SyncMetadataPayload(
                lastModifiedByDeviceID: syncState.lastModifiedByDeviceID,
                lastModifiedAt: syncState.lastModifiedAt,
                syncVersion: syncState.syncVersion,
                isDeleted: syncState.isDeleted
            )
        )
    }

    static func makeEnvelopes(from records: [SegmentRecord]) throws -> [SegmentEnvelope] {
        try records.map(makeEnvelope)
    }
}
