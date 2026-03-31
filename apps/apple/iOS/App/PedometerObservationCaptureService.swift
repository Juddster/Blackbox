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

    func backfill(from startDate: Date, to endDate: Date) async -> Bool {
        let data = await historicalData(from: startDate, to: endDate)
        guard let data else {
            return false
        }

        let input = ObservationInput(
            timestamp: data.endDate,
            sourceDevice: .iPhone,
            sourceType: .pedometer,
            payload: self.payload(for: data, startDate: startDate, endDate: endDate, isHistorical: true)
        )

        do {
            try self.recorder.record(input)
            return true
        } catch {
            return false
        }
    }

    func historicalDataPointCount(from startDate: Date, to endDate: Date) async -> Int? {
        let data = await historicalData(from: startDate, to: endDate)
        return data == nil ? 0 : 1
    }

    private func historicalData(from startDate: Date, to endDate: Date) async -> CMPedometerData? {
        guard CMPedometer.isStepCountingAvailable(), endDate > startDate else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: startDate, to: endDate) { [weak self] data, error in
                guard self != nil, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }

    private func record(data: CMPedometerData) throws {
        let input = ObservationInput(
            timestamp: data.endDate,
            sourceDevice: .iPhone,
            sourceType: .pedometer,
            payload: payload(for: data, startDate: data.startDate, endDate: data.endDate, isHistorical: false)
        )

        try recorder.record(input)
    }

    private func payload(
        for data: CMPedometerData,
        startDate: Date,
        endDate: Date,
        isHistorical: Bool
    ) -> String {
        var components = [
            "start=\(startDate.timeIntervalSince1970)",
            "end=\(endDate.timeIntervalSince1970)",
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

        if isHistorical {
            components.append("historical=true")
            components.append("origin=systemHistory")
        } else {
            components.append("origin=live")
        }

        return components.joined(separator: ";")
    }
}
