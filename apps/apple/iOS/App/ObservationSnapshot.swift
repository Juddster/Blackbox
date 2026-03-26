import Foundation

struct ObservationSnapshot: Identifiable {
    let id: UUID
    let sourceType: ObservationSourceType
    let title: String
    let detail: String
    let timestamp: Date
    let qualityHint: String?
}
