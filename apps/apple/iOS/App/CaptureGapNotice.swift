import Foundation

struct CaptureGapNotice: Equatable {
    let startTime: Date
    let endTime: Date
    let recoveredSources: [CaptureServiceKind]
    let blockingReasons: [String]

    var message: String {
        let window = "\(startTime.formatted(date: .omitted, time: .shortened)) to \(endTime.formatted(date: .omitted, time: .shortened))"
        let reasons = blockingReasons.joined(separator: " ")

        if recoveredSources.isEmpty {
            return "Blackbox could not fully collect in the background from \(window). \(reasons)"
        }

        let recovered = recoveredSources.map(\.displayName).joined(separator: ", ")
        return "Blackbox recovered \(recovered) data from \(window), but could not fully collect in the background. \(reasons)"
    }
}
