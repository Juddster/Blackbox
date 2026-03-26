import Foundation
import SwiftData

@MainActor
struct LocalSegmentInterpretationEditor {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func updateUserSelectedClass(
        for segmentID: UUID,
        label: String
    ) throws {
        let records = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        guard let record = records.first(where: { $0.id == segmentID }) else {
            return
        }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let userSelectedClass = trimmedLabel.isEmpty ? nil : trimmedLabel

        guard let interpretation = record.interpretation else {
            return
        }

        interpretation.userSelectedClass = userSelectedClass
        interpretation.needsReview = false
        interpretation.ambiguityState = .clear
        interpretation.interpretationOrigin = userSelectedClass == nil ? .system : .user
        interpretation.updatedAt = .now

        record.updatedAt = .now

        if let syncState = record.syncState {
            syncState.lastModifiedByDeviceID = "apple-local"
            syncState.lastModifiedAt = .now
            syncState.disposition = .pendingUpload
            syncState.lastSyncError = nil
            syncState.pendingServerEnvelopeData = nil
        } else {
            record.syncState = SegmentSyncStateRecord(
                lastModifiedByDeviceID: "apple-local",
                lastModifiedAt: .now,
                syncVersion: 0,
                disposition: .pendingUpload
            )
        }

        try modelContext.save()
    }
}
