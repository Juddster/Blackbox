import MapKit
import UniformTypeIdentifiers
import SwiftData
import SwiftUI

struct DataView: View {
    @Environment(\.modelContext) private var modelContext
    let syncActivity: SyncActivityStore

    @State private var recentObservations = [ObservationSnapshot]()
    @State private var inferencePreview: ReplayInferencePreview?
    @State private var exportStartTime = Date.now.addingTimeInterval(-60 * 60)
    @State private var exportEndTime = Date.now
    @State private var exportDocument: ReplayExportDocument?
    @State private var exportFileName = "blackbox-replay.json"
    @State private var isPresentingExporter = false
    @State private var exportStatusMessage: String?
    @State private var inferenceStatusMessage: String?
    @State private var debugSelection: ReplayInferenceDebugSelection?

    var body: some View {
        NavigationStack {
            List {
                SyncStatusSection(
                    pendingCount: syncActivity.pendingCount,
                    conflictedCount: syncActivity.conflictedCount,
                    conflicts: syncActivity.conflicts,
                    isSyncing: syncActivity.isSyncing,
                    lastPushMessage: syncActivity.lastPushMessage,
                    lastSyncAt: syncActivity.lastSyncAt,
                    onPushPending: pushPendingSync
                )

                Section("Replay Export") {
                    DatePicker(
                        "Start",
                        selection: $exportStartTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "End",
                        selection: $exportEndTime,
                        in: exportStartTime...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Button {
                        exportReplayBundle()
                    } label: {
                        Label("Export Replay Bundle", systemImage: "square.and.arrow.up")
                    }
                    .disabled(exportEndTime <= exportStartTime)

                    if let exportStatusMessage {
                        Text(exportStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Inference Preview") {
                    Button {
                        analyzeSelectedWindow()
                    } label: {
                        Label("Analyze Selected Window", systemImage: "waveform.path.ecg.rectangle")
                    }
                    .disabled(exportEndTime <= exportStartTime)

                    if let inferencePreview, inferencePreview.proposedSegments.isEmpty == false {
                        Button {
                            saveInferredSegments()
                        } label: {
                            Label("Save Proposed Segments", systemImage: "square.and.arrow.down")
                        }
                    }

                    if let inferenceStatusMessage {
                        Text(inferenceStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let inferencePreview {
                        Text(inferenceSummary(for: inferencePreview))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if inferencePreview.proposedTransitions.isEmpty == false {
                            ForEach(inferencePreview.proposedTransitions) { transition in
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(
                                        "\(transition.fromActivityClass.displayName) → \(transition.toActivityClass.displayName)",
                                        systemImage: "flag.checkered.2.crossed"
                                    )
                                    .font(.subheadline.weight(.semibold))

                                    Text(
                                        "\(transition.timestamp.formatted(date: .omitted, time: .shortened)) • confidence \(Int((transition.confidence * 100).rounded()))%"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    if transition.reasonSummary.isEmpty == false {
                                        Text(transition.reasonSummary)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if inferencePreview.proposedSegments.isEmpty {
                            Text("No confident automatic segments were inferred for this window.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(inferencePreview.proposedSegments) { segment in
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(segment.activityClass.displayName, systemImage: segment.activityClass.systemImage)
                                        .font(.headline)

                                    Text(
                                        "\(segment.startTime.formatted(date: .omitted, time: .shortened)) - \(segment.endTime.formatted(date: .omitted, time: .shortened))"
                                    )
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                    Text(inferenceMetricsText(for: segment))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    if segment.reasonSummary.isEmpty == false {
                                        Text(segment.reasonSummary)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        if inferencePreview.suppressedSegments.isEmpty == false {
                            Section("Suppressed Debug Segments") {
                                ForEach(inferencePreview.suppressedSegments) { segment in
                                    Button {
                                        debugSelection = ReplayInferenceDebugSelection(
                                            segment: segment,
                                            laneTitle: "Suppressed Debug Segment"
                                        )
                                    } label: {
                                        debugSegmentRow(segment: segment, systemImage: "eye.slash")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if inferencePreview.rejectedSegments.isEmpty == false {
                            Section("Rejected Debug Segments") {
                                ForEach(inferencePreview.rejectedSegments) { segment in
                                    Button {
                                        debugSelection = ReplayInferenceDebugSelection(
                                            segment: segment,
                                            laneTitle: "Rejected Debug Segment"
                                        )
                                    } label: {
                                        debugSegmentRow(segment: segment, systemImage: "exclamationmark.triangle")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                RecentObservationsSection(observations: recentObservations)
            }
            .navigationTitle("Data")
        }
        .task {
            refreshRecentObservations()
            configureExportWindowIfNeeded()
        }
        .fileExporter(
            isPresented: $isPresentingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                exportStatusMessage = "Replay bundle exported."
            case .failure:
                exportStatusMessage = "Could not export the replay bundle."
            }
        }
        .sheet(item: $debugSelection) { selection in
            ReplayInferenceDebugMapView(selection: selection)
        }
    }

    private func pushPendingSync() async {
        await syncActivity.pushPending(using: modelContext)
        refreshRecentObservations()
    }

    private func refreshRecentObservations() {
        var descriptor = FetchDescriptor<ObservationRecord>(
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        let observations = (try? modelContext.fetch(descriptor)) ?? []
        recentObservations = ObservationProjection.recent(from: observations)
    }

    private func configureExportWindowIfNeeded() {
        guard exportStatusMessage == nil else {
            return
        }

        var newestDescriptor = FetchDescriptor<ObservationRecord>(
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .reverse)]
        )
        newestDescriptor.fetchLimit = 1

        var oldestDescriptor = FetchDescriptor<ObservationRecord>(
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )
        oldestDescriptor.fetchLimit = 1

        let newestObservation = try? modelContext.fetch(newestDescriptor).first
        let oldestObservation = try? modelContext.fetch(oldestDescriptor).first

        if let newestObservation {
            exportEndTime = newestObservation.timestamp
            exportStartTime = max(
                oldestObservation?.timestamp ?? newestObservation.timestamp.addingTimeInterval(-60 * 60),
                newestObservation.timestamp.addingTimeInterval(-60 * 90)
            )
        }
    }

    private func exportReplayBundle() {
        let observations = fetchObservationsForExport()
        let segments = fetchSegmentsForExport()
        refreshMetricsForExport(segments: segments)
        let analysis = ReplayInferenceAnalyzer.preview(
            from: observations,
            windowStart: exportStartTime,
            windowEnd: exportEndTime
        )
        let bundle = ReplayExportBundle(
            exportedAt: .now,
            windowStart: exportStartTime,
            windowEnd: exportEndTime,
            observations: observations.map(ReplayExportObservation.init),
            segments: segments.compactMap(makeReplayExportSegment),
            analysis: ReplayExportAnalysis(preview: analysis)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(bundle) else {
            exportStatusMessage = "Could not encode the replay bundle."
            return
        }

        exportDocument = ReplayExportDocument(data: data)
        exportFileName = exportFileName(for: bundle)
        exportStatusMessage = "Prepared \(bundle.observations.count) observations and \(bundle.segments.count) segments."
        isPresentingExporter = true
    }

    private func refreshMetricsForExport(segments: [SegmentRecord]) {
        guard segments.isEmpty == false else {
            return
        }

        let backfiller = LocalSegmentMetricBackfiller(modelContext: modelContext)
        for segment in segments where segment.lifecycleState != .deleted {
            try? backfiller.refreshMetrics(for: segment.id)
        }
    }

    private func analyzeSelectedWindow() {
        let observations = fetchObservationsForExport()
        inferencePreview = ReplayInferenceAnalyzer.preview(
            from: observations,
            windowStart: exportStartTime,
            windowEnd: exportEndTime
        )
        inferenceStatusMessage = nil
    }

    private func saveInferredSegments() {
        guard let inferencePreview else {
            inferenceStatusMessage = "Analyze a window before saving proposed segments."
            return
        }

        do {
            let writer = LocalUserSegmentWriter(modelContext: modelContext)
            let outcome = try writer.createInferredSegments(from: inferencePreview.proposedSegments)
            if outcome.createdCount == 0 {
                inferenceStatusMessage = outcome.skippedCount > 0
                    ? "Skipped \(outcome.skippedCount) overlapping proposals."
                    : "No saveable inferred segments were found."
            } else if outcome.skippedCount == 0 {
                inferenceStatusMessage = "Saved \(outcome.createdCount) proposed segment\(outcome.createdCount == 1 ? "" : "s") for review."
            } else {
                inferenceStatusMessage = "Saved \(outcome.createdCount) proposed segment\(outcome.createdCount == 1 ? "" : "s"); skipped \(outcome.skippedCount) overlaps."
            }
        } catch {
            inferenceStatusMessage = "Could not save the proposed segments."
        }
    }

    private func fetchObservationsForExport() -> [ObservationRecord] {
        let startTime = exportStartTime
        let endTime = exportEndTime
        let descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            },
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchSegmentsForExport() -> [SegmentRecord] {
        let startTime = exportStartTime
        let endTime = exportEndTime
        let descriptor = FetchDescriptor<SegmentRecord>(
            predicate: #Predicate<SegmentRecord> { segment in
                segment.endTime >= startTime && segment.startTime <= endTime
            },
            sortBy: [SortDescriptor(\SegmentRecord.startTime, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func makeReplayExportSegment(from record: SegmentRecord) -> ReplayExportSegment? {
        guard let envelope = try? SyncEnvelopeProjection.makeEnvelope(from: record) else {
            return nil
        }

        return ReplayExportSegment(
            id: record.id,
            title: record.title,
            startTime: record.startTime,
            endTime: record.endTime,
            lifecycleState: record.lifecycleState,
            originType: record.originType,
            interpretation: envelope.interpretation,
            summary: envelope.summary,
            sync: envelope.sync
        )
    }

    private func exportFileName(for bundle: ReplayExportBundle) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let start = formatter.string(from: bundle.windowStart).replacingOccurrences(of: ":", with: "-")
        let end = formatter.string(from: bundle.windowEnd).replacingOccurrences(of: ":", with: "-")
        return "blackbox-replay-\(start)-to-\(end).json"
    }
}

private struct ReplayExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct ReplayExportBundle: Codable {
    let exportedAt: Date
    let windowStart: Date
    let windowEnd: Date
    let observations: [ReplayExportObservation]
    let segments: [ReplayExportSegment]
    let analysis: ReplayExportAnalysis
}

private struct ReplayExportObservation: Codable {
    let id: UUID
    let timestamp: Date
    let sourceDevice: ObservationSourceDevice
    let sourceType: ObservationSourceType
    let captureOrigin: String
    let isManualLocationFix: Bool
    let payload: String
    let qualityHint: String?
    let ingestedAt: Date

    init(record: ObservationRecord) {
        let values = SegmentObservationMetrics.payloadValues(from: record.payload)
        id = record.id
        timestamp = record.timestamp
        sourceDevice = record.sourceDevice
        sourceType = record.sourceType
        if values["manual"] == "true" {
            captureOrigin = "manualCorrection"
        } else if values["historical"] == "true" || values["origin"] == "systemHistory" {
            captureOrigin = "systemHistory"
        } else {
            captureOrigin = values["origin"] ?? "live"
        }
        isManualLocationFix = values["manual"] == "true"
        payload = record.payload
        qualityHint = record.qualityHint
        ingestedAt = record.ingestedAt
    }
}

private struct ReplayExportSegment: Codable {
    let id: UUID
    let title: String
    let startTime: Date
    let endTime: Date
    let lifecycleState: SegmentLifecycleState
    let originType: SegmentOriginType
    let interpretation: SegmentInterpretationPayload?
    let summary: SegmentSummaryPayload?
    let sync: SyncMetadataPayload
}

private struct ReplayExportAnalysis: Codable {
    let analyzerVersion: String
    let bucketDurationSeconds: TimeInterval
    let locationFixCount: Int
    let motionRecordCount: Int
    let pedometerRecordCount: Int
    let proposedSegments: [ReplayExportAnalysisSegment]
    let proposedTransitions: [ReplayExportAnalysisTransition]

    init(preview: ReplayInferencePreview) {
        analyzerVersion = ReplayInferenceAnalyzer.heuristicVersion
        bucketDurationSeconds = preview.bucketDurationSeconds
        locationFixCount = preview.locationFixCount
        motionRecordCount = preview.motionRecordCount
        pedometerRecordCount = preview.pedometerRecordCount
        proposedSegments = preview.proposedSegments.map(ReplayExportAnalysisSegment.init)
        proposedTransitions = preview.proposedTransitions.map(ReplayExportAnalysisTransition.init)
        suppressedSegments = preview.suppressedSegments.map(ReplayExportAnalysisSegment.init)
        rejectedSegments = preview.rejectedSegments.map(ReplayExportAnalysisSegment.init)
    }

    let suppressedSegments: [ReplayExportAnalysisSegment]
    let rejectedSegments: [ReplayExportAnalysisSegment]
}

private struct ReplayExportAnalysisSegment: Codable {
    let startTime: Date
    let endTime: Date
    let activityClass: ActivityClass
    let confidence: Double
    let reasonSummary: String
    let locationDistanceMeters: Double
    let pedometerDistanceMeters: Double?
    let averageSpeedMetersPerSecond: Double?
    let averageCadenceStepsPerSecond: Double?

    init(segment: ReplayInferenceSegment) {
        startTime = segment.startTime
        endTime = segment.endTime
        activityClass = segment.activityClass
        confidence = segment.confidence
        reasonSummary = segment.reasonSummary
        locationDistanceMeters = segment.locationDistanceMeters
        pedometerDistanceMeters = segment.pedometerDistanceMeters
        averageSpeedMetersPerSecond = segment.averageSpeedMetersPerSecond
        averageCadenceStepsPerSecond = segment.averageCadenceStepsPerSecond
        rejectedLocationDistanceMeters = segment.rejectedLocationDistanceMeters
        rejectedLocationJumpCount = segment.rejectedLocationJumpCount
    }

    let rejectedLocationDistanceMeters: Double
    let rejectedLocationJumpCount: Int
}

private struct ReplayExportAnalysisTransition: Codable {
    let timestamp: Date
    let fromActivityClass: ActivityClass
    let toActivityClass: ActivityClass
    let confidence: Double
    let reasonSummary: String

    init(transition: ReplayInferenceTransition) {
        timestamp = transition.timestamp
        fromActivityClass = transition.fromActivityClass
        toActivityClass = transition.toActivityClass
        confidence = transition.confidence
        reasonSummary = transition.reasonSummary
    }
}

private extension DataView {
    func inferenceSummary(for preview: ReplayInferencePreview) -> String {
        let bucketMinutes = Int(preview.bucketDurationSeconds / 60)
        return "\(preview.locationFixCount) location, \(preview.motionRecordCount) motion, and \(preview.pedometerRecordCount) pedometer observations scored in \(bucketMinutes)-minute buckets."
    }

    func inferenceMetricsText(for segment: ReplayInferenceSegment) -> String {
        var parts = [
            "confidence \(Int((segment.confidence * 100).rounded()))%"
        ]

        let preferredDistanceMeters = segment.pedometerDistanceMeters ?? segment.locationDistanceMeters
        if preferredDistanceMeters > 0 {
            parts.append(
                Measurement(value: preferredDistanceMeters, unit: UnitLength.meters)
                    .formatted(.measurement(width: .abbreviated, usage: .road))
            )
        }

        if let averageSpeedMetersPerSecond = segment.averageSpeedMetersPerSecond {
            parts.append(
                Measurement(value: averageSpeedMetersPerSecond, unit: UnitSpeed.metersPerSecond)
                    .formatted(.measurement(width: .abbreviated))
            )
        }

        if let averageCadenceStepsPerSecond = segment.averageCadenceStepsPerSecond {
            parts.append(String(format: "%.2f steps/s", averageCadenceStepsPerSecond))
        }

        if segment.rejectedLocationJumpCount > 0 {
            parts.append("rejected jumps \(segment.rejectedLocationJumpCount)")
        }

        return parts.joined(separator: " • ")
    }

    @ViewBuilder
    func debugSegmentRow(segment: ReplayInferenceSegment, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(segment.activityClass.displayName, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))

            Text(
                "\(segment.startTime.formatted(date: .omitted, time: .shortened)) - \(segment.endTime.formatted(date: .omitted, time: .shortened))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(inferenceMetricsText(for: segment))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(segment.reasonSummary)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

private struct ReplayInferenceDebugSelection: Identifiable {
    let segment: ReplayInferenceSegment
    let laneTitle: String

    var id: String {
        "\(laneTitle)-\(segment.id)"
    }
}

private struct ReplayInferenceDebugMapView: View {
    @Environment(\.modelContext) private var modelContext

    let selection: ReplayInferenceDebugSelection

    @State private var observations = [ObservationRecord]()
    @State private var pathReview = SegmentPathReview(
        rawFixes: [],
        acceptedFixes: [],
        rejectedFixes: [],
        rejectedDistanceMeters: 0
    )
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            List {
                Section("Path Review") {
                    if pathReview.rawFixes.isEmpty {
                        Text("No location fixes were recorded in this interval.")
                            .foregroundStyle(.secondary)
                    } else {
                        Map(position: $cameraPosition) {
                            if pathReview.rawFixes.count >= 2 {
                                MapPolyline(coordinates: pathReview.rawFixes.map(\.coordinate))
                                    .stroke(.gray.opacity(0.55), lineWidth: 4)
                            }

                            if pathReview.acceptedFixes.count >= 2 {
                                MapPolyline(coordinates: pathReview.acceptedFixes.map(\.coordinate))
                                    .stroke(.blue, lineWidth: 5)
                            }

                            ForEach(pathReview.rejectedFixes) { fix in
                                Marker("Rejected", coordinate: fix.coordinate)
                                    .tint(.red)
                            }
                        }
                        .mapStyle(.standard(elevation: .flat))
                        .frame(minHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Blue is the cleaned path. Gray is the raw path. Red markers are rejected jump fixes.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Interval") {
                    LabeledContent("Lane", value: selection.laneTitle)
                    LabeledContent("Activity", value: selection.segment.activityClass.displayName)
                    LabeledContent(
                        "Window",
                        value: "\(selection.segment.startTime.formatted(date: .abbreviated, time: .shortened)) - \(selection.segment.endTime.formatted(date: .omitted, time: .shortened))"
                    )
                    LabeledContent("Confidence", value: "\(Int((selection.segment.confidence * 100).rounded()))%")
                    if selection.segment.reasonSummary.isEmpty == false {
                        Text(selection.segment.reasonSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Captured Evidence") {
                    ForEach(observationSummaryRows, id: \.label) { row in
                        LabeledContent(row.label, value: "\(row.count)")
                    }
                }
            }
            .navigationTitle("Inference Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: selection.id) {
            loadObservations()
        }
    }

    private var summaryText: String {
        let rejectedDistanceText = Measurement(
            value: pathReview.rejectedDistanceMeters,
            unit: UnitLength.meters
        )
        .formatted(.measurement(width: .abbreviated, usage: .road))

        return "\(pathReview.acceptedFixes.count) accepted fixes, \(pathReview.rejectedFixes.count) rejected fixes, \(rejectedDistanceText) rejected distance."
    }

    private var observationSummaryRows: [(label: String, count: Int)] {
        let groupedCounts = Dictionary(grouping: observations, by: \.sourceType)
            .map { sourceType, groupedObservations in
                (label: sourceTypeLabel(sourceType), count: groupedObservations.count)
            }
            .sorted { $0.label < $1.label }

        return groupedCounts.isEmpty ? [("Total", 0)] : [("Total", observations.count)] + groupedCounts
    }

    private func loadObservations() {
        let startTime = selection.segment.startTime
        let endTime = selection.segment.endTime
        var descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            },
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = 4_000

        observations = (try? modelContext.fetch(descriptor)) ?? []
        pathReview = SegmentObservationMetrics.pathReview(from: observations)
        if pathReview.rawFixes.isEmpty == false {
            cameraPosition = initialMapPosition(for: pathReview.rawFixes)
        }
    }

    private func initialMapPosition(for locationFixes: [SegmentLocationFix]) -> MapCameraPosition {
        let points = locationFixes.map(\.coordinate).map(MKMapPoint.init)
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
