import SwiftData

extension ModelContainer {
    static var blackbox: ModelContainer = {
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

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create Blackbox model container: \(error)")
        }
    }()
}
