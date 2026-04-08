import SwiftData

extension ModelContainer {
    static func makeBlackbox() throws -> ModelContainer {
        let schema = Schema([
            ObservationRecord.self,
            SegmentRecord.self,
            SegmentInterpretationRecord.self,
            SegmentSummaryRecord.self,
            SegmentSyncStateRecord.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
