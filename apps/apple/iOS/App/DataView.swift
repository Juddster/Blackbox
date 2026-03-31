import UniformTypeIdentifiers
import SwiftData
import SwiftUI

struct DataView: View {
    @Environment(\.modelContext) private var modelContext
    let syncActivity: SyncActivityStore

    @State private var recentObservations = [ObservationSnapshot]()
    @State private var exportStartTime = Date.now.addingTimeInterval(-60 * 60)
    @State private var exportEndTime = Date.now
    @State private var exportDocument: ReplayExportDocument?
    @State private var exportFileName = "blackbox-replay.json"
    @State private var isPresentingExporter = false
    @State private var exportStatusMessage: String?

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
        let bundle = ReplayExportBundle(
            exportedAt: .now,
            windowStart: exportStartTime,
            windowEnd: exportEndTime,
            observations: observations.map(ReplayExportObservation.init),
            segments: segments.compactMap(makeReplayExportSegment)
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
}

private struct ReplayExportObservation: Codable {
    let id: UUID
    let timestamp: Date
    let sourceDevice: ObservationSourceDevice
    let sourceType: ObservationSourceType
    let payload: String
    let qualityHint: String?
    let ingestedAt: Date

    init(record: ObservationRecord) {
        id = record.id
        timestamp = record.timestamp
        sourceDevice = record.sourceDevice
        sourceType = record.sourceType
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
