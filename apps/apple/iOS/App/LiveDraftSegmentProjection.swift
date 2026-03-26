import Foundation

enum LiveDraftSegmentProjection {
    static func make(from observations: [ObservationRecord], now: Date = .now) -> LiveDraftSegmentSnapshot? {
        let windowStart = now.addingTimeInterval(-20 * 60)
        let windowedObservations = observations
            .filter { $0.timestamp >= windowStart }
            .sorted { $0.timestamp < $1.timestamp }

        guard
            let firstObservation = windowedObservations.first,
            let lastObservation = windowedObservations.last
        else {
            return nil
        }

        let latestLocation = windowedObservations.last { $0.sourceType == .location }
        let latestMotion = windowedObservations.last { $0.sourceType == .motion }
        let latestPedometer = windowedObservations.last { $0.sourceType == .pedometer }

        let locationValues = latestLocation.map(payloadValues) ?? [:]
        let motionValues = latestMotion.map(payloadValues) ?? [:]
        let pedometerValues = latestPedometer.map(payloadValues) ?? [:]

        let speed = locationValues["speed"].flatMap(Double.init)
        let distanceMeters = pedometerValues["distance"].flatMap(Double.init)
        let cadence = pedometerValues["currentCadence"].flatMap(Double.init)

        let classification = classify(
            motionValues: motionValues,
            speed: speed,
            cadence: cadence,
            hasPedometerSignal: latestPedometer != nil
        )

        let supportingSources = ObservationSourceType.allCases.filter { sourceType in
            windowedObservations.contains { $0.sourceType == sourceType }
        }

        return LiveDraftSegmentSnapshot(
            title: classification.title,
            activityClass: classification.activityClass,
            startTime: firstObservation.timestamp,
            endTime: lastObservation.timestamp,
            confidence: classification.confidence,
            needsReview: classification.needsReview,
            supportingSources: supportingSources,
            distanceMeters: distanceMeters
        )
    }

    private static func classify(
        motionValues: [String: String],
        speed: Double?,
        cadence: Double?,
        hasPedometerSignal: Bool
    ) -> (title: String, activityClass: ActivityClass, confidence: Double, needsReview: Bool) {
        if motionValues["automotive"] == "true" || (speed ?? -1) >= 8 {
            return ("Draft vehicle segment", .vehicle, 0.72, false)
        }

        if motionValues["running"] == "true" || (cadence ?? -1) >= 2.2 || (speed ?? -1) >= 2.4 {
            return ("Draft run segment", .running, 0.68, false)
        }

        if motionValues["cycling"] == "true" || ((speed ?? -1) >= 4.5 && hasPedometerSignal == false) {
            return ("Draft cycling segment", .cycling, 0.58, true)
        }

        if motionValues["walking"] == "true" || hasPedometerSignal {
            return ("Draft walking segment", .walking, 0.63, false)
        }

        if motionValues["stationary"] == "true" {
            return ("Draft stationary segment", .stationary, 0.7, false)
        }

        return ("Draft unknown segment", .unknown, 0.35, true)
    }

    private static func payloadValues(for observation: ObservationRecord) -> [String: String] {
        observation.payload.split(separator: ";").reduce(into: [String: String]()) { partialResult, pair in
            let components = pair.split(separator: "=", maxSplits: 1)
            guard components.count == 2 else {
                return
            }

            partialResult[String(components[0])] = String(components[1])
        }
    }
}
