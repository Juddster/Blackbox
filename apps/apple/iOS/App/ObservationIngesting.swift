import Foundation

@MainActor
protocol ObservationIngesting {
    func record(_ input: ObservationInput) throws
    func record(_ inputs: [ObservationInput]) throws
}
