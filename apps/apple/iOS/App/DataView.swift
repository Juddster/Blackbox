import MapKit
import UniformTypeIdentifiers
import SwiftData
import SwiftUI

struct DataView: View {
    @Environment(\.modelContext) private var modelContext
    let syncActivity: SyncActivityStore
    let captureControl: CaptureControlStore

    @AppStorage("replay_export_start_time_interval") private var storedExportStartTimeInterval: Double = 0
    @AppStorage("replay_export_end_time_interval") private var storedExportEndTimeInterval: Double = 0
    @State private var recentObservations = [ObservationSnapshot]()
    @State private var isRecentObservationsExpanded = false
    @State private var inferencePreview: ReplayInferencePreview?
    @State private var exportStartTime = Date.now.addingTimeInterval(-60 * 60)
    @State private var exportEndTime = Date.now
    @State private var exportDocument: ReplayExportDocument?
    @State private var exportFileName = "blackbox-replay.json"
    @State private var isPresentingExporter = false
    @State private var exportStatusMessage: String?
    @State private var inferenceStatusMessage: String?
    @State private var debugSelection: ReplayInferenceDebugSelection?
    @State private var exportObservationSummary = ReplayExportObservationSummary(observations: [])
    @State private var truthComparison: ReplayTruthComparison?

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

                if let latestResumeReport = captureControl.latestResumeReport {
                    Section("Background Collection Report") {
                        LabeledContent("Window", value: latestResumeReport.windowSummary)
                        LabeledContent("Intent", value: latestResumeReport.enabledSourcesSummary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recorded by Blackbox")
                                .font(.subheadline.weight(.semibold))
                            Text(latestResumeReport.recordedSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recovered On Resume")
                                .font(.subheadline.weight(.semibold))
                            Text(latestResumeReport.recoveredSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)

                        if latestResumeReport.blockingReasons.isEmpty == false {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes")
                                    .font(.subheadline.weight(.semibold))
                                Text(latestResumeReport.blockingReasons.joined(separator: "\n"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }

                        Button("Clear Report") {
                            captureControl.clearLatestResumeReport()
                        }
                    }
                }

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

                    Text(exportObservationSummary.uiSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

                        if let truthComparison {
                            Section("Health Truth Comparison") {
                                Text(truthComparison.summaryText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(truthComparison.healthMatches) { match in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Label(match.healthActivityClass.displayName, systemImage: "heart.text.square")
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            Text(match.statusText)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(match.statusColor)
                                        }

                                        Text(
                                            "\(match.startTime.formatted(date: .omitted, time: .shortened)) - \(match.endTime.formatted(date: .omitted, time: .shortened))"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                        if let inferredActivityClass = match.inferredActivityClass {
                                            Text(
                                                "Inferred \(inferredActivityClass.displayName) • truth coverage \(Int((match.truthCoverage * 100).rounded()))% • start \(formattedSignedDuration(match.startOffsetSeconds)) • end \(formattedSignedDuration(match.endOffsetSeconds))"
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                            if let distanceDeltaMeters = match.distanceDeltaMeters {
                                                Text("Distance delta \(formattedSignedDistance(distanceDeltaMeters))")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        } else {
                                            Text("No inferred segment overlapped this Health segment enough to count as a match.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }

                                if truthComparison.unmatchedProposedSegments.isEmpty == false {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Unmatched Proposed Segments")
                                            .font(.subheadline.weight(.semibold))
                                        ForEach(truthComparison.unmatchedProposedSegments) { segment in
                                            Text(
                                                "\(segment.activityClass.displayName) \(segment.startTime.formatted(date: .omitted, time: .shortened)) - \(segment.endTime.formatted(date: .omitted, time: .shortened))"
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

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

                RecentObservationsSection(
                    isExpanded: $isRecentObservationsExpanded,
                    observations: recentObservations
                )
            }
            .navigationTitle("Data")
        }
        .task {
            await configureExportWindowIfNeeded()
            await refreshExportObservationSummary()
        }
        .onChange(of: isRecentObservationsExpanded) { _, isExpanded in
            guard isExpanded else {
                return
            }

            Task {
                await refreshRecentObservations()
            }
        }
        .onChange(of: exportStartTime) { _, newValue in
            storedExportStartTimeInterval = newValue.timeIntervalSinceReferenceDate
            Task { await refreshExportObservationSummary() }
        }
        .onChange(of: exportEndTime) { _, newValue in
            storedExportEndTimeInterval = newValue.timeIntervalSinceReferenceDate
            Task { await refreshExportObservationSummary() }
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
        if isRecentObservationsExpanded {
            await refreshRecentObservations()
        }
    }

    private func refreshRecentObservations() async {
        let modelContainer = modelContext.container
        let snapshots = await Task.detached(priority: .utility) {
            var descriptor = FetchDescriptor<ObservationRecord>(
                sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = 40
            let observations = (try? ModelContext(modelContainer).fetch(descriptor)) ?? []
            return ObservationProjection.recent(from: observations)
        }.value
        recentObservations = snapshots
    }

    private func configureExportWindowIfNeeded() async {
        if storedExportStartTimeInterval > 0, storedExportEndTimeInterval > 0 {
            let storedStartTime = Date(timeIntervalSinceReferenceDate: storedExportStartTimeInterval)
            let storedEndTime = Date(timeIntervalSinceReferenceDate: storedExportEndTimeInterval)
            if storedEndTime > storedStartTime {
                exportStartTime = storedStartTime
                exportEndTime = storedEndTime
                return
            }
        }

        guard exportStatusMessage == nil else {
            return
        }

        let modelContainer = modelContext.container
        let bounds = await Task.detached(priority: .utility) {
            var newestDescriptor = FetchDescriptor<ObservationRecord>(
                sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .reverse)]
            )
            newestDescriptor.fetchLimit = 1

            var oldestDescriptor = FetchDescriptor<ObservationRecord>(
                sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
            )
            oldestDescriptor.fetchLimit = 1

            let context = ModelContext(modelContainer)
            return (
                newest: try? context.fetch(newestDescriptor).first?.timestamp,
                oldest: try? context.fetch(oldestDescriptor).first?.timestamp
            )
        }.value

        if let newestObservation = bounds.newest {
            exportEndTime = newestObservation
            exportStartTime = max(
                bounds.oldest ?? newestObservation.addingTimeInterval(-60 * 60),
                newestObservation.addingTimeInterval(-60 * 90)
            )
        }
    }

    private func exportReplayBundle() {
        let modelContainer = modelContext.container
        let exportStartTime = exportStartTime
        let exportEndTime = exportEndTime
        Task {
            do {
                let result = try await Task.detached(priority: .utility) {
                    try Self.buildReplayExport(
                        modelContainer: modelContainer,
                        exportStartTime: exportStartTime,
                        exportEndTime: exportEndTime
                    )
                }.value

                exportDocument = ReplayExportDocument(data: result.data)
                exportFileName = result.fileName
                exportStatusMessage = result.statusMessage
                isPresentingExporter = true
            } catch {
                exportStatusMessage = "Could not encode the replay bundle."
            }
        }
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
        let modelContainer = modelContext.container
        let exportStartTime = exportStartTime
        let exportEndTime = exportEndTime
        Task {
            let result = await Task.detached(priority: .utility) {
                let context = ModelContext(modelContainer)
                let observations = Self.fetchObservationsForExport(
                    using: context,
                    startTime: exportStartTime,
                    endTime: exportEndTime
                )
                let segments = Self.fetchSegmentsForExport(
                    using: context,
                    startTime: exportStartTime,
                    endTime: exportEndTime
                )
                let preview = ReplayInferenceAnalyzer.preview(
                    from: observations,
                    windowStart: exportStartTime,
                    windowEnd: exportEndTime
                )
                let comparison = Self.makeTruthComparison(
                    preview: preview,
                    segments: segments
                )
                return (preview, comparison)
            }.value
            inferencePreview = result.0
            truthComparison = result.1
            inferenceStatusMessage = nil
        }
    }

    private func saveInferredSegments() {
        guard let inferencePreview else {
            inferenceStatusMessage = "Analyze a window before saving proposed segments."
            return
        }

        let modelContainer = modelContext.container
        Task {
            do {
                let outcome = try await Task.detached(priority: .utility) {
                    let writer = LocalUserSegmentWriter(modelContainer: modelContainer)
                    return try writer.createInferredSegments(from: inferencePreview.proposedSegments)
                }.value

                if outcome.createdCount == 0 {
                    inferenceStatusMessage = outcome.skippedCount > 0
                        ? "Replaced \(outcome.replacedCount) stale system segment\(outcome.replacedCount == 1 ? "" : "s"); skipped \(outcome.skippedCount) protected overlap\(outcome.skippedCount == 1 ? "" : "s")."
                        : "No saveable inferred segments were found."
                } else if outcome.skippedCount == 0, outcome.replacedCount == 0 {
                    inferenceStatusMessage = "Saved \(outcome.createdCount) proposed segment\(outcome.createdCount == 1 ? "" : "s") for review."
                } else if outcome.skippedCount == 0 {
                    inferenceStatusMessage = "Replaced \(outcome.replacedCount) stale system segment\(outcome.replacedCount == 1 ? "" : "s") and saved \(outcome.createdCount) proposed segment\(outcome.createdCount == 1 ? "" : "s")."
                } else {
                    inferenceStatusMessage = "Replaced \(outcome.replacedCount) stale system segment\(outcome.replacedCount == 1 ? "" : "s"), saved \(outcome.createdCount) proposed segment\(outcome.createdCount == 1 ? "" : "s"), and skipped \(outcome.skippedCount) protected overlap\(outcome.skippedCount == 1 ? "" : "s")."
                }
            } catch {
                inferenceStatusMessage = "Could not save the proposed segments."
            }
        }
    }

    private func refreshExportObservationSummary() async {
        let modelContainer = modelContext.container
        let exportStartTime = exportStartTime
        let exportEndTime = exportEndTime
        exportObservationSummary = await Task.detached(priority: .utility) {
            let observations = Self.fetchObservationsForExport(
                using: ModelContext(modelContainer),
                startTime: exportStartTime,
                endTime: exportEndTime
            )
            return ReplayExportObservationSummary(observations: observations)
        }.value
    }

    nonisolated private static func fetchObservationsForExport(
        using modelContext: ModelContext,
        startTime: Date,
        endTime: Date
    ) -> [ObservationRecord] {
        let descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate<ObservationRecord> { observation in
                observation.timestamp >= startTime && observation.timestamp <= endTime
            },
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    nonisolated private static func fetchSegmentsForExport(
        using modelContext: ModelContext,
        startTime: Date,
        endTime: Date
    ) -> [SegmentRecord] {
        let descriptor = FetchDescriptor<SegmentRecord>(
            predicate: #Predicate<SegmentRecord> { segment in
                segment.endTime >= startTime && segment.startTime <= endTime
            },
            sortBy: [SortDescriptor(\SegmentRecord.startTime, order: .forward)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.lifecycleState != .deleted }
    }

    nonisolated private static func makeReplayExportSegment(from record: SegmentRecord) -> ReplayExportSegment? {
        guard let envelope = try? SyncEnvelopeProjection.makeEnvelope(from: record) else {
            return nil
        }

        return ReplayExportSegment(
            id: record.id,
            title: record.title,
            startTime: record.startTime,
            startTimeLocal: ReplayExportLocalTime.string(from: record.startTime),
            endTime: record.endTime,
            endTimeLocal: ReplayExportLocalTime.string(from: record.endTime),
            lifecycleState: record.lifecycleState,
            originType: record.originType,
            interpretation: envelope.interpretation,
            summary: envelope.summary,
            sync: envelope.sync
        )
    }
}

private extension DataView {
    nonisolated static func buildReplayExport(
        modelContainer: ModelContainer,
        exportStartTime: Date,
        exportEndTime: Date
    ) throws -> ReplayExportBuildResult {
        let modelContext = ModelContext(modelContainer)
        let observations = fetchObservationsForExport(
            using: modelContext,
            startTime: exportStartTime,
            endTime: exportEndTime
        )
        let segments = fetchSegmentsForExport(
            using: modelContext,
            startTime: exportStartTime,
            endTime: exportEndTime
        )
        let observationSummary = ReplayExportObservationSummary(observations: observations)
        let backfiller = LocalSegmentMetricBackfiller(modelContainer: modelContainer)
        for segment in segments where segment.lifecycleState != .deleted {
            try? backfiller.refreshMetrics(for: segment.id)
        }
        let analysis = ReplayInferenceAnalyzer.preview(
            from: observations,
            windowStart: exportStartTime,
            windowEnd: exportEndTime
        )
        let truthComparison = makeTruthComparison(
            preview: analysis,
            segments: segments
        )
        let bundle = ReplayExportBundle(
            exportedAt: .now,
            exportedTimeZoneIdentifier: TimeZone.current.identifier,
            exportedTimeZoneSecondsFromGMT: TimeZone.current.secondsFromGMT(),
            windowStart: exportStartTime,
            windowEnd: exportEndTime,
            appBuilds: ReplayExportAppBuilds(
                iPhone: .current,
                latestWatchSender: WatchIntakeMetadataSnapshot.load()
            ),
            observationSummary: observationSummary,
            observations: observations.map(ReplayExportObservation.init),
            segments: segments.compactMap(Self.makeReplayExportSegment),
            analysis: ReplayExportAnalysis(preview: analysis, truthComparison: truthComparison)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)

        return ReplayExportBuildResult(
            data: data,
            fileName: exportFileName(for: bundle),
            statusMessage: "Prepared \(bundle.observations.count) observations (\(observationSummary.iPhoneObservationCount) iPhone, \(observationSummary.watchObservationCount) watch) and \(bundle.segments.count) segments."
        )
    }

    nonisolated static func exportFileName(for bundle: ReplayExportBundle) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let start = formatter.string(from: bundle.windowStart).replacingOccurrences(of: ":", with: "-")
        let end = formatter.string(from: bundle.windowEnd).replacingOccurrences(of: ":", with: "-")
        return "blackbox-replay-\(start)-to-\(end).json"
    }
}

private struct ReplayExportBuildResult: Sendable {
    let data: Data
    let fileName: String
    let statusMessage: String
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
    let exportedTimeZoneIdentifier: String
    let exportedTimeZoneSecondsFromGMT: Int
    let windowStart: Date
    let windowEnd: Date
    let appBuilds: ReplayExportAppBuilds
    let observationSummary: ReplayExportObservationSummary
    let observations: [ReplayExportObservation]
    let segments: [ReplayExportSegment]
    let analysis: ReplayExportAnalysis
}

private struct ReplayExportAppBuilds: Codable {
    let iPhone: AppBuildInfo
    let latestWatchSender: ReplayExportWatchSenderBuild?

    init(iPhone: AppBuildInfo, latestWatchSender: WatchIntakeMetadataSnapshot?) {
        self.iPhone = iPhone
        self.latestWatchSender = latestWatchSender.map(ReplayExportWatchSenderBuild.init)
    }
}

private struct ReplayExportWatchSenderBuild: Codable {
    let captureSessionID: UUID
    let batchSequence: Int
    let sentAt: Date
    let shortVersion: String
    let buildNumber: String
    let observationCount: Int
    let transport: String

    init(metadata: WatchIntakeMetadataSnapshot) {
        captureSessionID = metadata.captureSessionID
        batchSequence = metadata.batchSequence
        sentAt = metadata.sentAt
        shortVersion = metadata.senderAppVersion
        buildNumber = metadata.senderBuildNumber
        observationCount = metadata.observationCount
        transport = metadata.transport
    }
}

private struct ReplayExportObservationSummary: Codable {
    let totalObservationCount: Int
    let iPhoneObservationCount: Int
    let watchObservationCount: Int
    let healthKitBackfillObservationCount: Int
    let liveWatchObservationCount: Int
    let healthKitBackfillWatchObservationCount: Int
    let healthKitBackfillIPhoneObservationCount: Int
    let locationCount: Int
    let motionCount: Int
    let pedometerCount: Int
    let heartRateCount: Int
    let watchLocationCount: Int
    let watchMotionCount: Int
    let watchPedometerCount: Int
    let watchHeartRateCount: Int
    let healthKitBackfillLocationCount: Int
    let healthKitBackfillPedometerCount: Int
    let healthKitBackfillHeartRateCount: Int

    init(observations: [ObservationRecord]) {
        let healthBackfillObservations = observations.filter { observation in
            observation.payload.contains("origin=healthKitBackfill")
        }
        let healthBackfillWatchObservations = healthBackfillObservations.filter { observation in
            observation.sourceDevice == .watch
        }
        let healthBackfillIPhoneObservations = healthBackfillObservations.filter { observation in
            observation.sourceDevice == .iPhone
        }
        let liveWatchObservations = observations.filter { observation in
            observation.sourceDevice == .watch && observation.payload.contains("origin=healthKitBackfill") == false
        }
        totalObservationCount = observations.count
        iPhoneObservationCount = observations.filter { $0.sourceDevice == .iPhone }.count
        watchObservationCount = observations.filter { $0.sourceDevice == .watch }.count
        healthKitBackfillObservationCount = healthBackfillObservations.count
        liveWatchObservationCount = liveWatchObservations.count
        healthKitBackfillWatchObservationCount = healthBackfillWatchObservations.count
        healthKitBackfillIPhoneObservationCount = healthBackfillIPhoneObservations.count
        locationCount = observations.filter { $0.sourceType == .location }.count
        motionCount = observations.filter { $0.sourceType == .motion }.count
        pedometerCount = observations.filter { $0.sourceType == .pedometer }.count
        heartRateCount = observations.filter { $0.sourceType == .heartRate }.count
        watchLocationCount = observations.filter { $0.sourceDevice == .watch && $0.sourceType == .location }.count
        watchMotionCount = observations.filter { $0.sourceDevice == .watch && $0.sourceType == .motion }.count
        watchPedometerCount = observations.filter { $0.sourceDevice == .watch && $0.sourceType == .pedometer }.count
        watchHeartRateCount = observations.filter { $0.sourceDevice == .watch && $0.sourceType == .heartRate }.count
        healthKitBackfillLocationCount = healthBackfillObservations.filter { $0.sourceType == .location }.count
        healthKitBackfillPedometerCount = healthBackfillObservations.filter { $0.sourceType == .pedometer }.count
        healthKitBackfillHeartRateCount = healthBackfillObservations.filter { $0.sourceType == .heartRate }.count
    }

    var uiSummary: String {
        "\(totalObservationCount) observations • \(iPhoneObservationCount) iPhone • \(watchObservationCount) watch • \(liveWatchObservationCount) live watch • \(healthKitBackfillObservationCount) Health backfill • \(locationCount) location • \(motionCount) motion • \(pedometerCount) pedometer • \(heartRateCount) heart rate"
    }
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
    let startTimeLocal: String
    let endTime: Date
    let endTimeLocal: String
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
    let truthComparison: ReplayExportTruthComparison?

    init(preview: ReplayInferencePreview, truthComparison: ReplayTruthComparison?) {
        analyzerVersion = ReplayInferenceAnalyzer.heuristicVersion
        bucketDurationSeconds = preview.bucketDurationSeconds
        locationFixCount = preview.locationFixCount
        motionRecordCount = preview.motionRecordCount
        pedometerRecordCount = preview.pedometerRecordCount
        proposedSegments = preview.proposedSegments.map(ReplayExportAnalysisSegment.init)
        proposedTransitions = preview.proposedTransitions.map(ReplayExportAnalysisTransition.init)
        self.truthComparison = truthComparison.map(ReplayExportTruthComparison.init)
        suppressedSegments = preview.suppressedSegments.map(ReplayExportAnalysisSegment.init)
        rejectedSegments = preview.rejectedSegments.map(ReplayExportAnalysisSegment.init)
    }

    let suppressedSegments: [ReplayExportAnalysisSegment]
    let rejectedSegments: [ReplayExportAnalysisSegment]
}

private struct ReplayExportAnalysisSegment: Codable {
    let startTime: Date
    let startTimeLocal: String
    let endTime: Date
    let endTimeLocal: String
    let activityClass: ActivityClass
    let confidence: Double
    let reasonSummary: String
    let locationDistanceMeters: Double
    let pedometerDistanceMeters: Double?
    let iPhonePedometerDistanceMeters: Double?
    let watchPedometerDistanceMeters: Double?
    let averageSpeedMetersPerSecond: Double?
    let averageCadenceStepsPerSecond: Double?

    init(segment: ReplayInferenceSegment) {
        startTime = segment.startTime
        startTimeLocal = ReplayExportLocalTime.string(from: segment.startTime)
        endTime = segment.endTime
        endTimeLocal = ReplayExportLocalTime.string(from: segment.endTime)
        activityClass = segment.activityClass
        confidence = segment.confidence
        reasonSummary = segment.reasonSummary
        locationDistanceMeters = segment.locationDistanceMeters
        pedometerDistanceMeters = segment.pedometerDistanceMeters
        iPhonePedometerDistanceMeters = segment.iPhonePedometerDistanceMeters
        watchPedometerDistanceMeters = segment.watchPedometerDistanceMeters
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
    let timestampLocal: String
    let fromActivityClass: ActivityClass
    let toActivityClass: ActivityClass
    let confidence: Double
    let reasonSummary: String

    init(transition: ReplayInferenceTransition) {
        timestamp = transition.timestamp
        timestampLocal = ReplayExportLocalTime.string(from: transition.timestamp)
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

        if let watchPedometerDistanceMeters = segment.watchPedometerDistanceMeters {
            parts.append("watch pedometer \(formattedDistance(watchPedometerDistanceMeters))")
        }

        if let iPhonePedometerDistanceMeters = segment.iPhonePedometerDistanceMeters {
            parts.append("iPhone pedometer \(formattedDistance(iPhonePedometerDistanceMeters))")
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

    func formattedDistance(_ distanceMeters: Double) -> String {
        Measurement(value: distanceMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    func formattedSignedDistance(_ distanceMeters: Double) -> String {
        let distanceText = formattedDistance(abs(distanceMeters))
        return distanceMeters >= 0 ? "+\(distanceText)" : "-\(distanceText)"
    }

    func formattedSignedDuration(_ seconds: TimeInterval) -> String {
        let magnitude = Int(abs(seconds).rounded())
        let minutes = magnitude / 60
        let remainingSeconds = magnitude % 60
        let body = minutes > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(remainingSeconds)s"
        return seconds >= 0 ? "+\(body)" : "-\(body)"
    }
}

private extension DataView {
    nonisolated static func makeTruthComparison(
        preview: ReplayInferencePreview,
        segments: [SegmentRecord]
    ) -> ReplayTruthComparison? {
        let healthSegments = segments.compactMap(ReplayTruthSegment.init)
        guard healthSegments.isEmpty == false else {
            return nil
        }

        let proposedSegments = preview.proposedSegments.filter { $0.activityClass != .stationary }
        let matches = healthSegments.map { healthSegment in
            makeTruthMatch(for: healthSegment, proposedSegments: proposedSegments)
        }
        let matchedProposedIDs = Set(matches.compactMap(\.matchedProposedSegmentID))
        let unmatchedProposedSegments = proposedSegments.filter { matchedProposedIDs.contains($0.id) == false }
        return ReplayTruthComparison(
            healthMatches: matches,
            unmatchedProposedSegments: unmatchedProposedSegments
        )
    }

    nonisolated static func makeTruthMatch(
        for healthSegment: ReplayTruthSegment,
        proposedSegments: [ReplayInferenceSegment]
    ) -> ReplayTruthMatch {
        let candidates = proposedSegments.compactMap { proposedSegment -> (ReplayInferenceSegment, TimeInterval)? in
            let overlap = overlapDuration(
                startA: healthSegment.startTime,
                endA: healthSegment.endTime,
                startB: proposedSegment.startTime,
                endB: proposedSegment.endTime
            )
            guard overlap > 0 else {
                return nil
            }
            return (proposedSegment, overlap)
        }

        guard let bestCandidate = candidates.max(by: { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 < rhs.1
            }
            let lhsAgreement = lhs.0.activityClass == healthSegment.activityClass ? 1 : 0
            let rhsAgreement = rhs.0.activityClass == healthSegment.activityClass ? 1 : 0
            if lhsAgreement != rhsAgreement {
                return lhsAgreement < rhsAgreement
            }
            return lhs.0.confidence < rhs.0.confidence
        }) else {
            return ReplayTruthMatch(healthSegment: healthSegment, proposedSegment: nil, overlapDuration: 0)
        }

        let minimumMatchOverlap = min(5 * 60, max(60, healthSegment.durationSeconds * 0.2))
        guard bestCandidate.1 >= minimumMatchOverlap else {
            return ReplayTruthMatch(healthSegment: healthSegment, proposedSegment: nil, overlapDuration: bestCandidate.1)
        }

        return ReplayTruthMatch(
            healthSegment: healthSegment,
            proposedSegment: bestCandidate.0,
            overlapDuration: bestCandidate.1
        )
    }

    nonisolated static func overlapDuration(
        startA: Date,
        endA: Date,
        startB: Date,
        endB: Date
    ) -> TimeInterval {
        max(0, min(endA, endB).timeIntervalSince(max(startA, startB)))
    }
}

private struct ReplayTruthSegment {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let activityClass: ActivityClass
    let distanceMeters: Double?

    var durationSeconds: TimeInterval {
        max(0, endTime.timeIntervalSince(startTime))
    }

    init?(record: SegmentRecord) {
        guard
            record.originType == .healthKitBackfill,
            record.lifecycleState != .deleted,
            let activityClass = record.interpretation?.visibleClass
        else {
            return nil
        }

        id = record.id
        startTime = record.startTime
        endTime = record.endTime
        self.activityClass = activityClass
        distanceMeters = record.summary?.distanceMeters
    }
}

private struct ReplayTruthComparison {
    let healthMatches: [ReplayTruthMatch]
    let unmatchedProposedSegments: [ReplayInferenceSegment]

    var summaryText: String {
        let matchedCount = healthMatches.filter(\.isMatched).count
        let classAgreementCount = healthMatches.filter(\.isClassMatch).count
        let strongCoverageCount = healthMatches.filter { $0.truthCoverage >= 0.8 }.count
        return "\(healthMatches.count) Health truth segment\(healthMatches.count == 1 ? "" : "s") • \(matchedCount) matched • \(classAgreementCount) class-aligned • \(strongCoverageCount) covered >=80% • \(unmatchedProposedSegments.count) unmatched proposed"
    }
}

private struct ReplayTruthMatch: Identifiable {
    let id: UUID
    let healthSegmentID: UUID
    let matchedProposedSegmentID: UUID?
    let healthActivityClass: ActivityClass
    let inferredActivityClass: ActivityClass?
    let startTime: Date
    let endTime: Date
    let overlapDuration: TimeInterval
    let truthCoverage: Double
    let inferredCoverage: Double
    let startOffsetSeconds: TimeInterval
    let endOffsetSeconds: TimeInterval
    let distanceDeltaMeters: Double?

    init(healthSegment: ReplayTruthSegment, proposedSegment: ReplayInferenceSegment?, overlapDuration: TimeInterval) {
        id = healthSegment.id
        healthSegmentID = healthSegment.id
        matchedProposedSegmentID = proposedSegment?.id
        healthActivityClass = healthSegment.activityClass
        inferredActivityClass = proposedSegment?.activityClass
        startTime = healthSegment.startTime
        endTime = healthSegment.endTime
        self.overlapDuration = overlapDuration

        let truthDuration = max(1, healthSegment.durationSeconds)
        truthCoverage = overlapDuration / truthDuration
        if let proposedSegment {
            let inferredDuration = max(1, proposedSegment.endTime.timeIntervalSince(proposedSegment.startTime))
            inferredCoverage = overlapDuration / inferredDuration
            startOffsetSeconds = proposedSegment.startTime.timeIntervalSince(healthSegment.startTime)
            endOffsetSeconds = proposedSegment.endTime.timeIntervalSince(healthSegment.endTime)
            let proposedDistance = proposedSegment.pedometerDistanceMeters ?? proposedSegment.locationDistanceMeters
            if let healthDistance = healthSegment.distanceMeters {
                distanceDeltaMeters = proposedDistance - healthDistance
            } else {
                distanceDeltaMeters = nil
            }
        } else {
            inferredCoverage = 0
            startOffsetSeconds = 0
            endOffsetSeconds = 0
            distanceDeltaMeters = nil
        }
    }

    var isMatched: Bool {
        matchedProposedSegmentID != nil
    }

    var isClassMatch: Bool {
        inferredActivityClass == healthActivityClass
    }

    var statusText: String {
        guard let inferredActivityClass else {
            return "MISS"
        }
        return inferredActivityClass == healthActivityClass ? "MATCH" : "MISMATCH"
    }

    var statusColor: Color {
        guard let inferredActivityClass else {
            return .red
        }
        return inferredActivityClass == healthActivityClass ? .green : .orange
    }
}

private struct ReplayExportTruthComparison: Codable {
    let healthMatches: [ReplayExportTruthMatch]
    let unmatchedProposedSegments: [ReplayExportAnalysisSegment]

    init(comparison: ReplayTruthComparison) {
        healthMatches = comparison.healthMatches.map(ReplayExportTruthMatch.init)
        unmatchedProposedSegments = comparison.unmatchedProposedSegments.map(ReplayExportAnalysisSegment.init)
    }
}

private struct ReplayExportTruthMatch: Codable {
    let healthSegmentID: UUID
    let matchedProposedSegmentID: UUID?
    let healthActivityClass: ActivityClass
    let inferredActivityClass: ActivityClass?
    let startTime: Date
    let startTimeLocal: String
    let endTime: Date
    let endTimeLocal: String
    let overlapDurationSeconds: TimeInterval
    let truthCoverage: Double
    let inferredCoverage: Double
    let startOffsetSeconds: TimeInterval
    let endOffsetSeconds: TimeInterval
    let distanceDeltaMeters: Double?

    init(match: ReplayTruthMatch) {
        healthSegmentID = match.healthSegmentID
        matchedProposedSegmentID = match.matchedProposedSegmentID
        healthActivityClass = match.healthActivityClass
        inferredActivityClass = match.inferredActivityClass
        startTime = match.startTime
        startTimeLocal = ReplayExportLocalTime.string(from: match.startTime)
        endTime = match.endTime
        endTimeLocal = ReplayExportLocalTime.string(from: match.endTime)
        overlapDurationSeconds = match.overlapDuration
        truthCoverage = match.truthCoverage
        inferredCoverage = match.inferredCoverage
        startOffsetSeconds = match.startOffsetSeconds
        endOffsetSeconds = match.endOffsetSeconds
        distanceDeltaMeters = match.distanceDeltaMeters
    }
}

private struct ReplayInferenceDebugSelection: Identifiable {
    let segment: ReplayInferenceSegment
    let laneTitle: String

    var id: String {
        "\(laneTitle)-\(segment.id)"
    }
}

private enum ReplayExportLocalTime {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        return formatter.string(from: date)
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
        let modelContainer = modelContext.container
        let segment = selection.segment
        Task {
            let result = await Task.detached(priority: .utility) {
                let modelContext = ModelContext(modelContainer)
                let startTime = segment.startTime
                let endTime = segment.endTime
                var descriptor = FetchDescriptor<ObservationRecord>(
                    predicate: #Predicate<ObservationRecord> { observation in
                        observation.timestamp >= startTime && observation.timestamp <= endTime
                    },
                    sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .forward)]
                )
                descriptor.fetchLimit = 4_000

                let observations = (try? modelContext.fetch(descriptor)) ?? []
                let pathReview = SegmentObservationMetrics.pathReview(from: observations)
                return (observations, pathReview)
            }.value

            observations = result.0
            pathReview = result.1
            if pathReview.rawFixes.isEmpty == false {
                cameraPosition = initialMapPosition(for: pathReview.rawFixes)
            }
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
