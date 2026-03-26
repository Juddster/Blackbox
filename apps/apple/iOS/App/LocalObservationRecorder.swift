import Foundation
import SwiftData

@MainActor
final class LocalObservationRecorder: ObservationIngesting {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func record(_ input: ObservationInput) throws {
        modelContext.insert(ObservationRecord(input: input))
        try modelContext.save()
    }

    func record(_ inputs: [ObservationInput]) throws {
        for input in inputs {
            modelContext.insert(ObservationRecord(input: input))
        }

        try modelContext.save()
    }
}
