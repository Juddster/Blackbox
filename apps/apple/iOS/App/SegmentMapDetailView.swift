import MapKit
import SwiftData
import SwiftUI

struct SegmentMapDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let segment: SegmentSnapshot

    @State private var observations = [ObservationRecord]()
    @State private var locationFixes = [SegmentLocationFix]()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var scrubIndex = 0
    @State private var isAddingManualFix = false

    var body: some View {
        NavigationStack {
            List {
                Section("Path Review") {
                    if locationFixes.isEmpty {
                        Text("No recorded location path is available for this segment.")
                            .foregroundStyle(.secondary)
                    } else {
                        MapReader { proxy in
                            Map(position: $cameraPosition) {
                                if locationFixes.count >= 2 {
                                    MapPolyline(coordinates: locationFixes.map(\.coordinate))
                                        .stroke(.blue, lineWidth: 5)
                                }

                                Marker("Start", coordinate: locationFixes.first?.coordinate ?? scrubbedFix.coordinate)
                                    .tint(.green)
                                Marker("End", coordinate: locationFixes.last?.coordinate ?? scrubbedFix.coordinate)
                                    .tint(.red)
                                Marker("Scrub", coordinate: scrubbedFix.coordinate)
                                    .tint(.orange)
                            }
                            .mapStyle(.standard(elevation: .flat))
                            .onMapCameraChange(frequency: .continuous) { context in
                                visibleRegion = context.region
                            }
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { event in
                                        guard
                                            isAddingManualFix,
                                            let coordinate = proxy.convert(event.location, from: .local)
                                        else {
                                            return
                                        }

                                        addManualFix(at: coordinate)
                                    }
                            )
                        }
                        .frame(minHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        if locationFixes.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Slider(
                                    value: Binding(
                                        get: { Double(scrubIndex) },
                                        set: { scrubIndex = min(max(Int($0.rounded()), 0), locationFixes.count - 1) }
                                    ),
                                    in: 0...Double(locationFixes.count - 1),
                                    step: 1
                                )

                                HStack {
                                    Text(scrubbedFix.timestamp, format: .dateTime.hour().minute().second())
                                    Spacer()
                                    Text("Fix \(scrubIndex + 1) of \(locationFixes.count)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current fix")
                                .font(.subheadline.weight(.semibold))
                            Text(scrubbedFixSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            isAddingManualFix.toggle()
                        } label: {
                            Label(
                                isAddingManualFix ? "Tap The Map To Place The Fix" : "Add Manual Fix At Scrub Time",
                                systemImage: isAddingManualFix ? "hand.tap" : "plus.circle"
                            )
                        }

                        if isAddingManualFix {
                            Text("Tap the map to place a corrective location fix at \(scrubbedFix.timestamp.formatted(date: .omitted, time: .shortened)).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            deleteCurrentFix()
                        } label: {
                            Label("Delete Current Fix", systemImage: "trash")
                        }

                        Button(role: .destructive) {
                            deleteFixesInVisibleRegion()
                        } label: {
                            Label("Delete Fixes In Visible Map Area", systemImage: "map")
                        }
                        .disabled(visibleRegion == nil)
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
        .task(id: segment.id) {
            loadSegmentObservations()
        }
    }

    private var scrubbedFix: SegmentLocationFix {
        locationFixes[min(max(scrubIndex, 0), max(locationFixes.count - 1, 0))]
    }

    private var scrubbedFixSummary: String {
        let coordinate = "\(String(format: "%.5f", scrubbedFix.coordinate.latitude)), \(String(format: "%.5f", scrubbedFix.coordinate.longitude))"
        var parts = [coordinate]

        if let horizontalAccuracy = scrubbedFix.horizontalAccuracy {
            parts.append("±\(Measurement(value: horizontalAccuracy, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated)))")
        }

        if let speedMetersPerSecond = scrubbedFix.speedMetersPerSecond, speedMetersPerSecond >= 0 {
            parts.append(Measurement(value: speedMetersPerSecond, unit: UnitSpeed.metersPerSecond).formatted(.measurement(width: .abbreviated)))
        }

        if scrubbedFix.isManual {
            parts.append("manual")
        }

        return parts.joined(separator: " • ")
    }

    private var observationSummaryRows: [(label: String, count: Int)] {
        let groupedCounts = Dictionary(grouping: observations, by: \.sourceType)
            .map { sourceType, groupedObservations in
                (label: sourceTypeLabel(sourceType), count: groupedObservations.count)
            }
            .sorted { $0.label < $1.label }

        return groupedCounts.isEmpty ? [("Total", 0)] : [("Total", observations.count)] + groupedCounts
    }

    private func loadSegmentObservations() {
        let startTime = segment.startTime
        let endTime = segment.endTime
        var descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            },
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = 4_000

        observations = (try? modelContext.fetch(descriptor)) ?? []
        locationFixes = SegmentObservationMetrics.locationFixes(from: observations)

        if locationFixes.isEmpty == false {
            scrubIndex = min(scrubIndex, locationFixes.count - 1)
            cameraPosition = initialMapPosition(for: locationFixes)
        }
    }

    private func deleteCurrentFix() {
        deleteFixes(matching: [scrubbedFix.observationID])
    }

    private func deleteFixesInVisibleRegion() {
        guard let visibleRegion else {
            return
        }

        let matchingIDs = locationFixes
            .filter { contains($0.coordinate, in: visibleRegion) }
            .map(\.observationID)
        deleteFixes(matching: matchingIDs)
    }

    private func deleteFixes(matching observationIDs: [UUID]) {
        guard observationIDs.isEmpty == false else {
            return
        }

        let recordsByID = Dictionary(uniqueKeysWithValues: observations.map { ($0.id, $0) })
        for observationID in observationIDs {
            if let record = recordsByID[observationID] {
                modelContext.delete(record)
            }
        }

        try? modelContext.save()
        let backfiller = LocalSegmentMetricBackfiller(modelContext: modelContext)
        try? backfiller.refreshMetrics(for: segment.id)
        loadSegmentObservations()
    }

    private func addManualFix(at coordinate: CLLocationCoordinate2D) {
        let timestamp = scrubbedFix.timestamp
        let payload = [
            "lat=\(coordinate.latitude)",
            "lon=\(coordinate.longitude)",
            "alt=0",
            "speed=-1",
            "course=-1",
            "hAcc=5",
            "vAcc=-1",
            "manual=true",
        ]
        .joined(separator: ";")

        let record = ObservationRecord(
            timestamp: timestamp,
            sourceDevice: .iPhone,
            sourceType: .location,
            payload: payload,
            qualityHint: "manual-fix"
        )

        modelContext.insert(record)
        try? modelContext.save()

        let backfiller = LocalSegmentMetricBackfiller(modelContext: modelContext)
        try? backfiller.refreshMetrics(for: segment.id)
        isAddingManualFix = false
        loadSegmentObservations()
    }

    private func initialMapPosition(for locationFixes: [SegmentLocationFix]) -> MapCameraPosition {
        let coordinates = locationFixes.map(\.coordinate)
        let points = coordinates.map(MKMapPoint.init)
        guard let firstPoint = points.first else {
            return .automatic
        }

        let rect = points.dropFirst().reduce(
            MKMapRect(origin: firstPoint, size: MKMapSize(width: 0, height: 0))
        ) { partialResult, point in
            partialResult.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }

        return .rect(rect)
    }

    private func contains(_ coordinate: CLLocationCoordinate2D, in region: MKCoordinateRegion) -> Bool {
        let latitudeDelta = region.span.latitudeDelta / 2
        let longitudeDelta = region.span.longitudeDelta / 2

        return coordinate.latitude >= region.center.latitude - latitudeDelta
            && coordinate.latitude <= region.center.latitude + latitudeDelta
            && coordinate.longitude >= region.center.longitude - longitudeDelta
            && coordinate.longitude <= region.center.longitude + longitudeDelta
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
}
