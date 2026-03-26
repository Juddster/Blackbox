import SwiftUI

struct TimelineSummarySection: View {
    let summary: TimelineSummary

    var body: some View {
        Section("Today") {
            LabeledContent("Segments", value: "\(summary.segmentCount)")
            LabeledContent("Observations", value: "\(summary.observationCount)")
            LabeledContent("Pending Sync", value: "\(summary.pendingUploadCount)")

            if summary.conflictedCount > 0 {
                LabeledContent("Conflicts", value: "\(summary.conflictedCount)")
            }
        }
    }
}
