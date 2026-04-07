import Foundation
import SwiftData

@MainActor
final class LocalObservationRecorder: ObservationIngesting {
    private let modelContainer: ModelContainer

    init(modelContext: ModelContext) {
        self.modelContainer = modelContext.container
    }

    func record(_ input: ObservationInput) throws {
        let modelContext = ModelContext(modelContainer)
        modelContext.insert(ObservationRecord(input: input))
        try modelContext.save()
    }

    func record(_ inputs: [ObservationInput]) throws {
        guard inputs.isEmpty == false else {
            return
        }

        let modelContext = ModelContext(modelContainer)
        for input in inputs {
            modelContext.insert(ObservationRecord(input: input))
        }

        try modelContext.save()
    }
}
