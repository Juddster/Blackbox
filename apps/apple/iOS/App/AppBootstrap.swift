import Foundation
import SwiftData

@MainActor
enum AppBootstrap {
    static func prepareStore(modelContext: ModelContext) throws {
        let seedSegments = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
            .filter { segment in
            segment.syncState?.lastModifiedByDeviceID.hasPrefix("seed-") == true
        }

        guard seedSegments.isEmpty == false else {
            return
        }

        for segment in seedSegments {
            modelContext.delete(segment)
        }

        try modelContext.save()
    }
}
