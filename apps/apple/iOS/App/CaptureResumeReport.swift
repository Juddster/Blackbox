import Foundation

struct CaptureResumeReport: Identifiable, Equatable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let enabledSources: [CaptureServiceKind]
    let recordedCounts: [CaptureResumeSourceCount]
    let recoveredCounts: [CaptureResumeSourceCount]
    let blockingReasons: [String]

    var title: String {
        "Capture Summary"
    }

    var message: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let window = formatter.string(from: startTime, to: endTime)
        let enabled = enabledSources.isEmpty
            ? "none"
            : enabledSources.map(\.displayName).joined(separator: ", ")
        let recorded = sectionBody(for: recordedCounts)
        let recovered = sectionBody(for: recoveredCounts)

        var sections = [
            "Since \(window):",
            "Blackbox capture intent during this window: \(enabled)",
            "",
            "Recorded by Blackbox during the window:",
            recorded,
            "",
            "Recovered from iOS system history on resume:",
            recovered,
        ]

        if blockingReasons.isEmpty == false {
            sections.append("")
            sections.append("Notes:")
            sections.append(blockingReasons.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n")
    }

    private func sectionBody(for counts: [CaptureResumeSourceCount]) -> String {
        counts.map(\.message).joined(separator: "\n")
    }
}

struct CaptureResumeSourceCount: Equatable {
    let kind: CaptureServiceKind
    let count: Int

    var message: String {
        "\(kind.displayName): \(count)"
    }
}
