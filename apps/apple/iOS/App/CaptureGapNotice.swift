import Foundation

struct CaptureGapNotice: Equatable {
    let startTime: Date
    let endTime: Date
    let affectedSources: [CaptureServiceKind]

    var message: String {
        let window = "\(startTime.formatted(date: .omitted, time: .shortened)) to \(endTime.formatted(date: .omitted, time: .shortened))"
        let sources = affectedSources.map(\.displayName).joined(separator: ", ")
        return "Blackbox likely missed \(sources) capture from \(window) while the app was not active."
    }
}
