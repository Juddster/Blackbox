import Foundation

enum TimelineProjection {
    static func summary(
        segmentCount: Int,
        observationCount: Int,
        syncSummary: SyncSummary
    ) -> TimelineSummary {
        TimelineSummary(
            segmentCount: segmentCount,
            observationCount: observationCount,
            pendingUploadCount: syncSummary.pendingUploadCount,
            conflictedCount: syncSummary.conflictedCount
        )
    }

    static func groups(from records: [SegmentRecord]) -> [TimelineDayGroup] {
        let snapshots = visibleRecords(from: records).map(SegmentSnapshot.init)
        let calendar = Calendar.autoupdatingCurrent

        return Dictionary(grouping: snapshots) { snapshot in
            calendar.startOfDay(for: snapshot.startTime)
        }
        .map { day, snapshots in
            TimelineDayGroup(
                day: day,
                segments: snapshots.sorted { $0.startTime > $1.startTime }
            )
        }
        .sorted { $0.day > $1.day }
    }

    static func visibleSegmentCount(from records: [SegmentRecord]) -> Int {
        visibleRecords(from: records).count
    }

    private static func visibleRecords(from records: [SegmentRecord]) -> [SegmentRecord] {
        records.filter { record in
            record.lifecycleState != .deleted
                && record.syncState?.isDeleted != true
                && LocalDeletedSegmentStore.contains(record.id) == false
        }
    }
}
