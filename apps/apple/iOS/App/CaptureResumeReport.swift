import Foundation

struct CaptureResumeReport: Identifiable, Equatable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let sourceCounts: [CaptureResumeSourceCount]
    let blockingReasons: [String]

    var title: String {
        "Capture Summary"
    }

    var message: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let window = formatter.string(from: startTime, to: endTime)
        let counts = sourceCounts.map(\.message).joined(separator: "\n")

        if blockingReasons.isEmpty {
            return "Since \(window):\n\(counts)"
        }

        return "Since \(window):\n\(counts)\n\nNotes:\n\(blockingReasons.joined(separator: "\n"))"
    }
}

struct CaptureResumeSourceCount: Equatable {
    let kind: CaptureServiceKind
    let count: Int

    var message: String {
        "\(kind.displayName): \(count)"
    }
}
