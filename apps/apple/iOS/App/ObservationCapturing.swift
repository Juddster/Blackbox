import Foundation

@MainActor
protocol ObservationCapturing {
    var isCapturing: Bool { get }
    func start() async throws
    func stop()
}
