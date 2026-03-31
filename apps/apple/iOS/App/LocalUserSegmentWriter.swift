import Foundation
import SwiftData

@MainActor
struct LocalUserSegmentWriter {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createSegment(
        startTime: Date,
        endTime: Date,
        activityClass: ActivityClass,
        narrowerLabel: String,
        distanceMeters: Double?
    ) throws {
        let trimmedLabel = narrowerLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationSeconds = max(0, endTime.timeIntervalSince(startTime))
        let distanceBreakdown = try distanceBreakdown(
            fallbackDistanceMeters: distanceMeters,
            activityClass: activityClass,
            startTime: startTime,
            endTime: endTime
        )
        let segment = SegmentRecord(
            startTime: startTime,
            endTime: endTime,
            lifecycleState: .settled,
            originType: .userCreated,
            primaryDeviceHint: .iPhone,
            title: title(for: activityClass, narrowerLabel: trimmedLabel)
        )

        segment.interpretation = SegmentInterpretationRecord(
            visibleClass: activityClass,
            userSelectedClass: trimmedLabel.isEmpty ? nil : trimmedLabel,
            confidence: 1,
            ambiguityState: .clear,
            needsReview: false,
            interpretationOrigin: .user
        )
        segment.summary = SegmentSummaryRecord(
            durationSeconds: durationSeconds,
            distanceMeters: distanceBreakdown.preferredDistanceMeters,
            locationDistanceMeters: distanceBreakdown.locationDistanceMeters,
            pedometerDistanceMeters: distanceBreakdown.pedometerDistanceMeters,
            averageSpeedMetersPerSecond: averageSpeed(
                distanceMeters: distanceBreakdown.preferredDistanceMeters,
                durationSeconds: durationSeconds
            )
        )
        segment.syncState = SegmentSyncStateRecord(
            lastModifiedByDeviceID: "apple-local",
            lastModifiedAt: .now,
            syncVersion: 0,
            disposition: .pendingUpload
        )

        modelContext.insert(segment)
        try modelContext.save()
    }

    func createInferredSegments(
        from proposals: [ReplayInferenceSegment]
    ) throws -> (createdCount: Int, skippedCount: Int) {
        let candidates = proposals.filter { $0.activityClass != .stationary }
        guard candidates.isEmpty == false else {
            return (0, 0)
        }

        let existingSegments = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        var createdCount = 0
        var skippedCount = 0

        for proposal in candidates {
            if hasSubstantialOverlap(for: proposal, existingSegments: existingSegments) {
                skippedCount += 1
                continue
            }

            let durationSeconds = max(0, proposal.endTime.timeIntervalSince(proposal.startTime))
            let preferredDistanceMeters = proposal.pedometerDistanceMeters ?? proposal.locationDistanceMeters
            let segment = SegmentRecord(
                startTime: proposal.startTime,
                endTime: proposal.endTime,
                lifecycleState: .unsettled,
                originType: .system,
                primaryDeviceHint: .iPhone,
                title: proposal.activityClass.displayName
            )

            segment.interpretation = SegmentInterpretationRecord(
                visibleClass: proposal.activityClass,
                confidence: proposal.confidence,
                ambiguityState: .uncertain,
                needsReview: true,
                interpretationOrigin: .system
            )
            segment.summary = SegmentSummaryRecord(
                durationSeconds: durationSeconds,
                distanceMeters: preferredDistanceMeters,
                locationDistanceMeters: proposal.locationDistanceMeters,
                pedometerDistanceMeters: proposal.pedometerDistanceMeters,
                averageSpeedMetersPerSecond: proposal.averageSpeedMetersPerSecond
            )
            segment.syncState = SegmentSyncStateRecord(
                lastModifiedByDeviceID: "apple-local",
                lastModifiedAt: .now,
                syncVersion: 0,
                disposition: .pendingUpload
            )

            modelContext.insert(segment)
            createdCount += 1
        }

        if createdCount > 0 {
            try modelContext.save()
        }

        return (createdCount, skippedCount)
    }

    func updateSegment(
        segmentID: UUID,
        startTime: Date,
        endTime: Date,
        activityClass: ActivityClass,
        narrowerLabel: String,
        distanceMeters: Double?
    ) throws {
        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        guard let segment = records.first(where: { $0.id == segmentID }) else {
            return
        }

        let trimmedLabel = narrowerLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationSeconds = max(0, endTime.timeIntervalSince(startTime))
        let distanceBreakdown = try distanceBreakdown(
            fallbackDistanceMeters: distanceMeters,
            activityClass: activityClass,
            startTime: startTime,
            endTime: endTime
        )

        segment.startTime = startTime
        segment.endTime = endTime
        segment.title = title(for: activityClass, narrowerLabel: trimmedLabel)
        segment.updatedAt = .now

        if let interpretation = segment.interpretation {
            interpretation.visibleClass = activityClass
            interpretation.userSelectedClass = trimmedLabel.isEmpty ? nil : trimmedLabel
            interpretation.confidence = 1
            interpretation.ambiguityState = .clear
            interpretation.needsReview = false
            interpretation.interpretationOrigin = .user
            interpretation.updatedAt = .now
        } else {
            segment.interpretation = SegmentInterpretationRecord(
                visibleClass: activityClass,
                userSelectedClass: trimmedLabel.isEmpty ? nil : trimmedLabel,
                confidence: 1,
                ambiguityState: .clear,
                needsReview: false,
                interpretationOrigin: .user
            )
        }

        if let summary = segment.summary {
            summary.durationSeconds = durationSeconds
            summary.distanceMeters = distanceBreakdown.preferredDistanceMeters
            summary.locationDistanceMeters = distanceBreakdown.locationDistanceMeters
            summary.pedometerDistanceMeters = distanceBreakdown.pedometerDistanceMeters
            summary.averageSpeedMetersPerSecond = averageSpeed(
                distanceMeters: distanceBreakdown.preferredDistanceMeters,
                durationSeconds: durationSeconds
            )
            summary.updatedAt = .now
        } else {
            segment.summary = SegmentSummaryRecord(
                durationSeconds: durationSeconds,
                distanceMeters: distanceBreakdown.preferredDistanceMeters,
                locationDistanceMeters: distanceBreakdown.locationDistanceMeters,
                pedometerDistanceMeters: distanceBreakdown.pedometerDistanceMeters,
                averageSpeedMetersPerSecond: averageSpeed(
                    distanceMeters: distanceBreakdown.preferredDistanceMeters,
                    durationSeconds: durationSeconds
                )
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

        try modelContext.save()
    }

    private func title(for activityClass: ActivityClass, narrowerLabel: String) -> String {
        if narrowerLabel.isEmpty == false {
            return narrowerLabel.replacingOccurrences(of: "-", with: " ").localizedCapitalized
        }

        return activityClass.displayName
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

    private func distanceBreakdown(
        fallbackDistanceMeters: Double?,
        activityClass: ActivityClass,
        startTime: Date,
        endTime: Date
    ) throws -> SegmentDistanceBreakdown {
        if let fallbackDistanceMeters {
            return SegmentDistanceBreakdown(
                preferredDistanceMeters: fallbackDistanceMeters,
                locationDistanceMeters: nil,
                pedometerDistanceMeters: nil
            )
        }

        let descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            },
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )
        let observations = try modelContext.fetch(descriptor)

        return SegmentObservationMetrics.distanceBreakdown(
            from: observations,
            preferredActivityClass: activityClass
        )
    }

    private func hasSubstantialOverlap(
        for proposal: ReplayInferenceSegment,
        existingSegments: [SegmentRecord]
    ) -> Bool {
        let proposalDuration = max(0, proposal.endTime.timeIntervalSince(proposal.startTime))
        guard proposalDuration > 0 else {
            return true
        }

        return existingSegments.contains { existingSegment in
            guard existingSegment.lifecycleState != .deleted else {
                return false
            }

            let overlapStart = max(existingSegment.startTime, proposal.startTime)
            let overlapEnd = min(existingSegment.endTime, proposal.endTime)
            let overlapDuration = overlapEnd.timeIntervalSince(overlapStart)
            guard overlapDuration > 0 else {
                return false
            }

            let existingDuration = max(0, existingSegment.endTime.timeIntervalSince(existingSegment.startTime))
            let overlapRatio = overlapDuration / proposalDuration
            let existingOverlapRatio = existingDuration > 0 ? overlapDuration / existingDuration : 0

            return overlapRatio >= 0.5 || existingOverlapRatio >= 0.5
        }
    }
}
