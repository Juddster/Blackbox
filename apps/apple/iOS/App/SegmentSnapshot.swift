import Foundation

struct SegmentSnapshot: Identifiable {
    let id: UUID
    let title: String
    let activityClass: ActivityClass
    let startTime: Date
    let endTime: Date
    let durationSeconds: TimeInterval
    let distanceMeters: Double?
    let needsReview: Bool
    let syncDisposition: SyncDisposition
    let syncErrorMessage: String?
    let canApplyServerVersion: Bool
    let canKeepLocalVersion: Bool

    init(record: SegmentRecord) {
        let selectedClass = record.interpretation?.userSelectedClass.flatMap(ActivityClass.init(rawValue:))
        let syncErrorMessage = record.syncState?.lastSyncError

        id = record.id
        title = record.title
        activityClass = selectedClass
            ?? record.interpretation?.visibleClass
            ?? .unknown
        startTime = record.startTime
        endTime = record.endTime
        durationSeconds = record.summary?.durationSeconds
            ?? record.endTime.timeIntervalSince(record.startTime)
        distanceMeters = record.summary?.distanceMeters
        needsReview = record.interpretation?.needsReview ?? false
        syncDisposition = record.syncState?.disposition ?? .pendingUpload
        self.syncErrorMessage = syncErrorMessage
        canApplyServerVersion = record.syncState?.pendingServerEnvelopeData != nil
        canKeepLocalVersion = record.syncState?.pendingServerEnvelopeData != nil
            && syncErrorMessage != "deletedOnServer"
    }
}
