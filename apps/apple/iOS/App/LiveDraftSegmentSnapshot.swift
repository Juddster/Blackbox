import Foundation

struct LiveDraftSegmentSnapshot {
    let title: String
    let activityClass: ActivityClass
    let startTime: Date
    let endTime: Date
    let confidence: Double
    let needsReview: Bool
    let supportingSources: [ObservationSourceType]
    let distanceMeters: Double?
}
