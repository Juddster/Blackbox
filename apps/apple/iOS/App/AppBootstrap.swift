import Foundation
import SwiftData

@MainActor
enum AppBootstrap {
    static func prepareStore(modelContext: ModelContext) throws {
        let segments = try modelContext.fetch(FetchDescriptor<SegmentRecord>())
        let observations = try modelContext.fetch(FetchDescriptor<ObservationRecord>())

        let seedSegments = segments.filter { segment in
            segment.syncState?.lastModifiedByDeviceID.hasPrefix("seed-") == true
        }
        let seedObservations = observations.filter { observation in
            observation.payload.hasPrefix("seed.")
        }

        guard seedSegments.isEmpty == false || seedObservations.isEmpty == false else {
            return
        }

        for segment in seedSegments {
            modelContext.delete(segment)
        }

        for observation in seedObservations {
            modelContext.delete(observation)
        }

        try modelContext.save()
    }
}
