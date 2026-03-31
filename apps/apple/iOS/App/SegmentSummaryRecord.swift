import Foundation
import SwiftData

@Model
final class SegmentSummaryRecord {
    @Attribute(.unique) var id: UUID
    var durationSeconds: TimeInterval
    var distanceMeters: Double?
    var locationDistanceMeters: Double?
    var pedometerDistanceMeters: Double?
    var elevationGainMeters: Double?
    var averageSpeedMetersPerSecond: Double?
    var maxSpeedMetersPerSecond: Double?
    var pauseCount: Int
    var updatedAt: Date

    @Relationship(inverse: \SegmentRecord.summary) var segment: SegmentRecord?

    init(
        id: UUID = UUID(),
        durationSeconds: TimeInterval,
        distanceMeters: Double? = nil,
        locationDistanceMeters: Double? = nil,
        pedometerDistanceMeters: Double? = nil,
        elevationGainMeters: Double? = nil,
        averageSpeedMetersPerSecond: Double? = nil,
        maxSpeedMetersPerSecond: Double? = nil,
        pauseCount: Int = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.locationDistanceMeters = locationDistanceMeters
        self.pedometerDistanceMeters = pedometerDistanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.maxSpeedMetersPerSecond = maxSpeedMetersPerSecond
        self.pauseCount = pauseCount
        self.updatedAt = updatedAt
    }
}
