@preconcurrency import CoreMotion
import Foundation

@MainActor
final class PedometerObservationCaptureService: ObservationCapturing {
    private let recorder: ObservationIngesting
    private let pedometer: CMPedometer

    private(set) var isCapturing: Bool = false

    init(recorder: ObservationIngesting) {
        self.recorder = recorder
        self.pedometer = CMPedometer()
    }

    func start() async throws {
        guard CMPedometer.isStepCountingAvailable(), isCapturing == false else {
            return
        }

        isCapturing = true

        pedometer.startUpdates(from: .now) { [weak self] data, _ in
            guard let self, let data else {
                return
            }

            Task { @MainActor in
                try? self.record(data: data)
            }
        }
    }

    func stop() {
        guard isCapturing else {
            return
        }

        isCapturing = false
        pedometer.stopUpdates()
    }

    private func record(data: CMPedometerData) throws {
        let input = ObservationInput(
            timestamp: data.endDate,
            sourceDevice: .iPhone,
            sourceType: .pedometer,
            payload: payload(for: data)
        )

        try recorder.record(input)
    }

    private func payload(for data: CMPedometerData) -> String {
        var components = [
            "steps=\(data.numberOfSteps)",
        ]

        if let distance = data.distance {
            components.append("distance=\(distance)")
        }

        if let floorsAscended = data.floorsAscended {
            components.append("floorsAscended=\(floorsAscended)")
        }

        if let floorsDescended = data.floorsDescended {
            components.append("floorsDescended=\(floorsDescended)")
        }

        if let currentPace = data.currentPace {
            components.append("currentPace=\(currentPace)")
        }

        if let currentCadence = data.currentCadence {
            components.append("currentCadence=\(currentCadence)")
        }

        return components.joined(separator: ";")
    }
}
