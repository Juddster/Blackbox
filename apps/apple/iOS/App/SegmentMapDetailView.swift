import MapKit
import SwiftUI

struct SegmentMapDetailView: View {
    let segment: SegmentSnapshot
    let observations: [ObservationRecord]

    var body: some View {
        NavigationStack {
            List {
                Section("Path") {
                    if locationCoordinates.isEmpty {
                        Text("No recorded location path is available for this segment.")
                            .foregroundStyle(.secondary)
                    } else {
                        Map(initialPosition: initialMapPosition) {
                            if locationCoordinates.count >= 2 {
                                MapPolyline(coordinates: locationCoordinates)
                                    .stroke(.blue, lineWidth: 5)
                            }

                            if let startCoordinate {
                                Marker("Start", coordinate: startCoordinate)
                                    .tint(.green)
                            }

                            if let endCoordinate {
                                Marker("End", coordinate: endCoordinate)
                                    .tint(.red)
                            }
                        }
                        .frame(minHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Section("Segment") {
                    LabeledContent("Title", value: segment.title)
                    LabeledContent("Activity", value: segment.activityLabel)
                    if let visibleClassLabel = segment.visibleClassLabel {
                        LabeledContent("Broad Class", value: visibleClassLabel)
                    }
                    LabeledContent(
                        "Window",
                        value: "\(segment.startTime.formatted(date: .abbreviated, time: .shortened)) - \(segment.endTime.formatted(date: .omitted, time: .shortened))"
                    )
                    LabeledContent(
                        "Duration",
                        value: Duration.seconds(segment.durationSeconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
                    )
                    if let distanceMeters = segment.distanceMeters {
                        LabeledContent(
                            "Distance",
                            value: Measurement(value: distanceMeters, unit: UnitLength.meters)
                                .formatted(.measurement(width: .abbreviated, usage: .road))
                        )
                    }
                }

                Section("Captured Evidence") {
                    ForEach(observationSummaryRows, id: \.label) { row in
                        LabeledContent(row.label, value: "\(row.count)")
                    }
                }
            }
            .navigationTitle("Segment")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var locationCoordinates: [CLLocationCoordinate2D] {
        observations.compactMap(locationCoordinate(from:))
    }

    private var startCoordinate: CLLocationCoordinate2D? {
        locationCoordinates.first
    }

    private var endCoordinate: CLLocationCoordinate2D? {
        locationCoordinates.last
    }

    private var initialMapPosition: MapCameraPosition {
        if let mapRect {
            return .rect(mapRect)
        }

        if let startCoordinate {
            return .region(
                MKCoordinateRegion(
                    center: startCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }

        return .automatic
    }

    private var mapRect: MKMapRect? {
        guard locationCoordinates.isEmpty == false else {
            return nil
        }

        let points = locationCoordinates.map(MKMapPoint.init)
        guard let firstPoint = points.first else {
            return nil
        }

        return points.dropFirst().reduce(
            MKMapRect(origin: firstPoint, size: MKMapSize(width: 0, height: 0))
        ) { partialResult, point in
            partialResult.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
    }

    private var observationSummaryRows: [(label: String, count: Int)] {
        let groupedCounts = Dictionary(grouping: observations, by: \.sourceType)
            .map { sourceType, groupedObservations in
                (label: sourceTypeLabel(sourceType), count: groupedObservations.count)
            }
            .sorted { $0.label < $1.label }

        return groupedCounts.isEmpty ? [("Total", 0)] : [("Total", observations.count)] + groupedCounts
    }

    private func sourceTypeLabel(_ sourceType: ObservationSourceType) -> String {
        switch sourceType {
        case .location:
            "Location"
        case .motion:
            "Motion"
        case .pedometer:
            "Pedometer"
        case .heartRate:
            "Heart Rate"
        case .deviceState:
            "Device State"
        case .connectivity:
            "Connectivity"
        case .other:
            "Other"
        }
    }

    private func locationCoordinate(from observation: ObservationRecord) -> CLLocationCoordinate2D? {
        guard observation.sourceType == .location else {
            return nil
        }

        let values = payloadValues(from: observation.payload)
        guard
            let latitude = values["lat"].flatMap(Double.init),
            let longitude = values["lon"].flatMap(Double.init)
        else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func payloadValues(from payload: String) -> [String: String] {
        payload.split(separator: ";").reduce(into: [String: String]()) { partialResult, pair in
            let components = pair.split(separator: "=", maxSplits: 1)
            guard components.count == 2 else {
                return
            }

            partialResult[String(components[0])] = String(components[1])
        }
    }
}
