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
