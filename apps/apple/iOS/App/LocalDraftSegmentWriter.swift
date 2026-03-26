import Foundation
import SwiftData

@MainActor
struct LocalDraftSegmentWriter {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func upsert(from draft: LiveDraftSegmentSnapshot) throws -> DraftSegmentWriteResult {
        let existingSegment = try existingActiveSystemSegment()
        let (segment, action) = prepareSegment(from: draft, existingSegment: existingSegment)

        segment.title = draft.title
        segment.startTime = min(segment.startTime, draft.startTime)
        segment.endTime = max(segment.endTime, draft.endTime)
        segment.lifecycleState = .active
        segment.originType = .system
        segment.primaryDeviceHint = .iPhone
        segment.updatedAt = .now

        if let interpretation = segment.interpretation {
            interpretation.visibleClass = draft.activityClass
            interpretation.confidence = draft.confidence
            interpretation.ambiguityState = draft.needsReview ? .uncertain : .clear
            interpretation.needsReview = draft.needsReview
            interpretation.interpretationOrigin = .system
            interpretation.updatedAt = .now
        } else {
            segment.interpretation = SegmentInterpretationRecord(
                visibleClass: draft.activityClass,
                confidence: draft.confidence,
                ambiguityState: draft.needsReview ? .uncertain : .clear,
                needsReview: draft.needsReview,
                interpretationOrigin: .system
            )
        }

        let durationSeconds = segment.endTime.timeIntervalSince(segment.startTime)

        if let summary = segment.summary {
            summary.durationSeconds = durationSeconds
            summary.distanceMeters = draft.distanceMeters
            summary.averageSpeedMetersPerSecond = averageSpeed(distanceMeters: draft.distanceMeters, durationSeconds: durationSeconds)
            summary.updatedAt = .now
        } else {
            segment.summary = SegmentSummaryRecord(
                durationSeconds: durationSeconds,
                distanceMeters: draft.distanceMeters,
                averageSpeedMetersPerSecond: averageSpeed(distanceMeters: draft.distanceMeters, durationSeconds: durationSeconds)
            )
        }

        if let syncState = segment.syncState {
            syncState.lastModifiedByDeviceID = "apple-local"
            syncState.lastModifiedAt = .now
            syncState.disposition = .pendingUpload
            syncState.lastSyncError = nil
        } else {
            segment.syncState = SegmentSyncStateRecord(
                lastModifiedByDeviceID: "apple-local",
                lastModifiedAt: .now,
                syncVersion: 0,
                disposition: .pendingUpload
            )
        }

        if segment !== existingSegment {
            modelContext.insert(segment)
        }

        try modelContext.save()
        return DraftSegmentWriteResult(
            segment: segment,
            action: action
        )
    }

    private func existingActiveSystemSegment() throws -> SegmentRecord? {
        let descriptor = FetchDescriptor<SegmentRecord>(
            sortBy: [SortDescriptor(\SegmentRecord.updatedAt, order: .reverse)]
        )
        let segments = try modelContext.fetch(descriptor)

        return segments.first {
            $0.lifecycleState == .active && $0.originType == .system
        }
    }

    private func prepareSegment(
        from draft: LiveDraftSegmentSnapshot,
        existingSegment: SegmentRecord?
    ) -> (SegmentRecord, DraftSegmentWriteAction) {
        guard let existingSegment else {
            return (makeSegment(from: draft), .created)
        }

        if shouldContinue(existingSegment: existingSegment, with: draft) {
            return (existingSegment, .updated)
        }

        finalize(existingSegment: existingSegment, boundary: draft.startTime)
        return (makeSegment(from: draft), .created)
    }

    private func shouldContinue(
        existingSegment: SegmentRecord,
        with draft: LiveDraftSegmentSnapshot
    ) -> Bool {
        let currentClass = existingSegment.interpretation?.visibleClass
        let gap = draft.startTime.timeIntervalSince(existingSegment.endTime)
        return currentClass == draft.activityClass && gap < 10 * 60
    }

    private func finalize(existingSegment: SegmentRecord, boundary: Date) {
        existingSegment.endTime = min(boundary, existingSegment.endTime.addingTimeInterval(10 * 60))
        existingSegment.lifecycleState = .unsettled
        existingSegment.updatedAt = .now

        if let summary = existingSegment.summary {
            summary.durationSeconds = existingSegment.endTime.timeIntervalSince(existingSegment.startTime)
            summary.updatedAt = .now
        }

        if let syncState = existingSegment.syncState {
            syncState.lastModifiedByDeviceID = "apple-local"
            syncState.lastModifiedAt = .now
            syncState.disposition = .pendingUpload
            syncState.lastSyncError = nil
        }
    }

    private func makeSegment(from draft: LiveDraftSegmentSnapshot) -> SegmentRecord {
        SegmentRecord(
            startTime: draft.startTime,
            endTime: draft.endTime,
            lifecycleState: .active,
            originType: .system,
            primaryDeviceHint: .iPhone,
            title: draft.title
        )
    }

    private func averageSpeed(distanceMeters: Double?, durationSeconds: TimeInterval) -> Double? {
        guard
            let distanceMeters,
            durationSeconds > 0
        else {
            return nil
        }

        return distanceMeters / durationSeconds
    }
}
