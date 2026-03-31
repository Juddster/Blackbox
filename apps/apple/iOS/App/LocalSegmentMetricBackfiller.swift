import Foundation
import SwiftData

@MainActor
struct LocalSegmentMetricBackfiller {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func backfillMissingDistanceMetrics() throws {
        let segments = try modelContext.fetch(FetchDescriptor<SegmentRecord>())

        for segment in segments {
            guard
                segment.lifecycleState != .deleted,
                let summary = segment.summary,
                summary.distanceMeters == nil
            else {
                continue
            }

            let observations = try observations(
                from: segment.startTime,
                to: segment.endTime
            )
            guard let distanceMeters = SegmentObservationMetrics.derivedDistanceMeters(from: observations) else {
                continue
            }

            summary.distanceMeters = distanceMeters
            if summary.durationSeconds > 0 {
                summary.averageSpeedMetersPerSecond = distanceMeters / summary.durationSeconds
            }
            summary.updatedAt = .now
            segment.updatedAt = .now
        }

        try modelContext.save()
    }

    func refreshMetrics(for segmentID: UUID) throws {
        let segments = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        guard let segment = segments.first(where: { $0.id == segmentID }) else {
            return
        }

        let observations = try observations(
            from: segment.startTime,
            to: segment.endTime
        )
        let distanceMeters = SegmentObservationMetrics.derivedDistanceMeters(from: observations)
        let durationSeconds = max(0, segment.endTime.timeIntervalSince(segment.startTime))
        let averageSpeedMetersPerSecond: Double?
        if let distanceMeters, durationSeconds > 0 {
            averageSpeedMetersPerSecond = distanceMeters / durationSeconds
        } else {
            averageSpeedMetersPerSecond = nil
        }

        if let summary = segment.summary {
            summary.distanceMeters = distanceMeters
            summary.durationSeconds = durationSeconds
            summary.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
            summary.updatedAt = .now
        } else {
            segment.summary = SegmentSummaryRecord(
                durationSeconds: durationSeconds,
                distanceMeters: distanceMeters,
                averageSpeedMetersPerSecond: averageSpeedMetersPerSecond
            )
        }

        segment.updatedAt = .now
        try modelContext.save()
    }

    private func observations(from startTime: Date, to endTime: Date) throws -> [ObservationRecord] {
        let descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            },
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )

        return try modelContext.fetch(descriptor)
    }
}
