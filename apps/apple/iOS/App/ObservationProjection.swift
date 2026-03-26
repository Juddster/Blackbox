import Foundation

enum ObservationProjection {
    static func recent(from observations: [ObservationRecord], limit: Int = 8) -> [ObservationSnapshot] {
        observations.prefix(limit).map(snapshot(from:))
    }

    private static func snapshot(from observation: ObservationRecord) -> ObservationSnapshot {
        ObservationSnapshot(
            id: observation.id,
            sourceType: observation.sourceType,
            title: title(for: observation.sourceType),
            detail: detail(for: observation),
            timestamp: observation.timestamp,
            qualityHint: observation.qualityHint
        )
    }

    private static func title(for sourceType: ObservationSourceType) -> String {
        switch sourceType {
        case .location:
            "Location Fix"
        case .motion:
            "Motion Activity"
        case .pedometer:
            "Pedometer Update"
        case .heartRate:
            "Heart Rate"
        case .deviceState:
            "Device State"
        case .connectivity:
            "Connectivity"
        case .other:
            "Observation"
        }
    }

    private static func detail(for observation: ObservationRecord) -> String {
        let values = payloadValues(from: observation.payload)

        switch observation.sourceType {
        case .location:
            return locationDetail(from: values)
        case .motion:
            return motionDetail(from: values)
        case .pedometer:
            return pedometerDetail(from: values)
        case .heartRate, .deviceState, .connectivity, .other:
            return observation.payload
        }
    }

    private static func locationDetail(from values: [String: String]) -> String {
        let latitude = values["lat"].flatMap(Double.init).map { String(format: "%.4f", $0) }
        let longitude = values["lon"].flatMap(Double.init).map { String(format: "%.4f", $0) }
        let speed = values["speed"].flatMap(Double.init)

        var parts = [String]()

        if let latitude, let longitude {
            parts.append("\(latitude), \(longitude)")
        }

        if let speed, speed >= 0 {
            let formattedSpeed = Measurement(value: speed, unit: UnitSpeed.metersPerSecond)
                .formatted(.measurement(width: .abbreviated))
            parts.append(formattedSpeed)
        }

        return parts.isEmpty ? "Recorded location sample" : parts.joined(separator: " • ")
    }

    private static func motionDetail(from values: [String: String]) -> String {
        let labels: [(String, String)] = [
            ("stationary", "Stationary"),
            ("walking", "Walking"),
            ("running", "Running"),
            ("cycling", "Cycling"),
            ("automotive", "Vehicle"),
            ("unknown", "Unknown"),
        ]

        let activeLabels = labels.compactMap { key, label in
            values[key] == "true" ? label : nil
        }

        return activeLabels.isEmpty ? "Recorded motion sample" : activeLabels.joined(separator: " • ")
    }

    private static func pedometerDetail(from values: [String: String]) -> String {
        var parts = [String]()

        if let steps = values["steps"] {
            parts.append("\(steps) steps")
        }

        if let distance = values["distance"].flatMap(Double.init) {
            let formattedDistance = Measurement(value: distance, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .road))
            parts.append(formattedDistance)
        }

        return parts.isEmpty ? "Recorded pedometer sample" : parts.joined(separator: " • ")
    }

    private static func payloadValues(from payload: String) -> [String: String] {
        payload.split(separator: ";").reduce(into: [String: String]()) { partialResult, pair in
            let components = pair.split(separator: "=", maxSplits: 1)
            guard components.count == 2 else {
                return
            }

            partialResult[String(components[0])] = String(components[1])
        }
    }
}
