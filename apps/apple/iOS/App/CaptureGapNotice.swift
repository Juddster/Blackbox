import Foundation

struct CaptureGapNotice: Equatable {
    let startTime: Date
    let endTime: Date
    let affectedSources: [CaptureServiceKind]
    let recoveredSources: [CaptureServiceKind]

    var message: String {
        let window = "\(startTime.formatted(date: .omitted, time: .shortened)) to \(endTime.formatted(date: .omitted, time: .shortened))"
        let missingSources = affectedSources.map(\.displayName).joined(separator: ", ")

        if affectedSources.isEmpty {
            let recovered = recoveredSources.map(\.displayName).joined(separator: ", ")
            return "Blackbox recovered \(recovered) data from \(window) after returning to the app."
        }

        if recoveredSources.isEmpty {
            return "Blackbox likely missed \(missingSources) capture from \(window) while the app was not active."
        }

        let recovered = recoveredSources.map(\.displayName).joined(separator: ", ")
        return "Blackbox recovered \(recovered) data from \(window), but likely still missed \(missingSources) capture while the app was not active."
    }
}
