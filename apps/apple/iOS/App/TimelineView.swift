import SwiftData
import SwiftUI

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    let syncActivity: SyncActivityStore
    private static let initialSegmentFetchLimit = 80
    private static let segmentFetchIncrement = 80

    @State private var liveDraftStatusMessage: String?
    @State private var inspectingSegment: SegmentSnapshot?
    @State private var editingManualSegment: SegmentSnapshot?
    @State private var isPresentingManualSegmentSheet = false
    @State private var manualSegmentStartTime = Date.now.addingTimeInterval(-30 * 60)
    @State private var manualSegmentEndTime = Date.now
    @State private var manualSegmentActivityClass: ActivityClass = .walking
    @State private var manualSegmentLabel = ""
    @State private var manualSegmentDistanceMeters = ""
    @State private var timelineRefreshNonce = 0
    @State private var recentObservations = [ObservationRecord]()
    @State private var segments = [SegmentRecord]()
    @State private var visibleSegmentLimit = TimelineView.initialSegmentFetchLimit
    @State private var hasMoreSegments = false

    var body: some View {
        NavigationStack {
            List {
                LiveDraftSegmentSection(
                    draft: liveDraftSegment,
                    statusMessage: liveDraftStatusMessage,
                    onPersistDraft: persistLiveDraft
                )

                if groupedSegments.isEmpty {
                    Section("Segments") {
                        Text("No saved segments yet. When Blackbox infers a current activity, save it here or mark a time window yourself.")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(groupedSegments) { group in
                    Section(group.title) {
                        ForEach(group.segments) { segment in
                            timelineRow(for: segment)
                        }
                    }
                }

                if hasMoreSegments {
                    Section {
                        Button("Load Older Segments") {
                            visibleSegmentLimit += TimelineView.segmentFetchIncrement
                            loadSegments()
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            prepareManualSegmentForm()
                            isPresentingManualSegmentSheet = true
                        } label: {
                            Label("Mark Segment", systemImage: "square.and.pencil")
                        }

                        Button {
                            prepareRecentWorkoutSegmentForm(activityClass: .running)
                            isPresentingManualSegmentSheet = true
                        } label: {
                            Label("Mark Recent Run", systemImage: "figure.run")
                        }

                        Button {
                            prepareRecentWorkoutSegmentForm(activityClass: .walking)
                            isPresentingManualSegmentSheet = true
                        } label: {
                            Label("Mark Recent Walk", systemImage: "figure.walk")
                        }
                    } label: {
                        Label("Mark Segment", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingManualSegmentSheet) {
            NavigationStack {
                Form {
                    Section("Time Window") {
                        DatePicker(
                            "Start",
                            selection: $manualSegmentStartTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        DatePicker(
                            "End",
                            selection: $manualSegmentEndTime,
                            in: manualSegmentStartTime...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    Section("Classification") {
                        Picker("Broad Activity", selection: $manualSegmentActivityClass) {
                            ForEach(ActivityClass.allCases) { activityClass in
                                Label(activityClass.displayName, systemImage: activityClass.systemImage)
                                    .tag(activityClass)
                            }
                        }

                        TextField("run, train, bus, indoor walk...", text: $manualSegmentLabel)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }

                    Section("Known Metrics") {
                        TextField("Distance meters (optional)", text: $manualSegmentDistanceMeters)
                            .keyboardType(.decimalPad)
                    }

                    if let observationCoverageDescription {
                        Section("Recorded Coverage") {
                            Text(observationCoverageDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Mark Segment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresentingManualSegmentSheet = false
                            editingManualSegment = nil
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await saveManualSegment()
                            }
                        }
                        .disabled(manualSegmentEndTime <= manualSegmentStartTime)
                    }
                }
            }
        }
        .sheet(item: $inspectingSegment) { segment in
            SegmentMapDetailView(segment: segment)
        }
        .task {
            await refreshRecentObservationsLoop()
        }
        .task(id: timelineRefreshNonce) {
            loadSegments()
        }
    }

    private var groupedSegments: [TimelineDayGroup] {
        let _ = timelineRefreshNonce
        let startTime = CFAbsoluteTimeGetCurrent()
        let groups = TimelineProjection.groups(from: segments)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("[Timeline] Projected \(segments.count) loaded segments into \(groups.count) day groups in \(String(format: "%.3f", elapsed))s.")
        return groups
    }

    private var liveDraftSegment: LiveDraftSegmentSnapshot? {
        LiveDraftSegmentProjection.make(from: recentObservations)
    }

    private var observationCoverageDescription: String? {
        guard
            let newestObservation = recentObservations.first?.timestamp,
            let oldestObservation = recentObservations.last?.timestamp
        else {
            return "No recorded observations yet."
        }

        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return "Local observations currently cover \(formatter.string(from: oldestObservation, to: newestObservation))."
    }

    private func persistLiveDraft() async {
        guard let liveDraftSegment else {
            liveDraftStatusMessage = "No current inferred activity is available yet."
            return
        }

        do {
            let writer = LocalDraftSegmentWriter(modelContext: modelContext)
            let result = try writer.upsert(from: liveDraftSegment)
            liveDraftStatusMessage = switch result.action {
            case .created:
                "Started a new segment for \(result.segment.title.lowercased())."
            case .updated:
                "Updated the current segment for \(result.segment.title.lowercased())."
            }
            refreshSyncActivity()
            await pushPendingSync()
        } catch {
            liveDraftStatusMessage = "Could not save the current inference."
        }
    }

    private func applyServerVersion(for segmentID: UUID) async {
        do {
            let coordinator = LocalSyncCoordinator()
            try coordinator.applyStoredServerEnvelope(
                for: segmentID,
                modelContext: modelContext
            )
            timelineRefreshNonce &+= 1
            refreshSyncActivity()
        } catch {
            syncActivity.lastPushMessage = "Could not apply the server version for that conflict."
        }
    }

    private func keepLocalVersion(for segmentID: UUID) async {
        do {
            let coordinator = LocalSyncCoordinator()
            try coordinator.requeueLocalVersion(
                for: segmentID,
                modelContext: modelContext
            )
            timelineRefreshNonce &+= 1
            refreshSyncActivity()
            await pushPendingSync()
        } catch {
            syncActivity.lastPushMessage = "Could not requeue the local version for that conflict."
        }
    }

    private func restoreDeletedSegment(for segmentID: UUID) async {
        do {
            let coordinator = LocalSyncCoordinator()
            try coordinator.restoreDeletedSegment(
                for: segmentID,
                modelContext: modelContext
            )
            timelineRefreshNonce &+= 1
            refreshSyncActivity()
            await pushPendingSync()
        } catch {
            syncActivity.lastPushMessage = "Could not restore that deleted segment."
        }
    }

    private func deleteSegment(for segmentID: UUID) async {
        do {
            let tombstoner = LocalSegmentTombstoner(modelContext: modelContext)
            try tombstoner.tombstone(segmentID: segmentID)
            timelineRefreshNonce &+= 1
            refreshSyncActivity()
            await pushPendingSync()
        } catch {
            syncActivity.lastPushMessage = "Could not delete that segment."
        }
    }

    private func currentEditableLabel(for segment: SegmentSnapshot) -> String {
        segment.visibleClassLabel == nil ? "" : segment.activityLabel
    }

    @ViewBuilder
    private func timelineRow(for segment: SegmentSnapshot) -> some View {
        let applyServerVersionAction = segment.canApplyServerVersion
            ? { await applyServerVersion(for: segment.id) }
            : nil
        let keepLocalVersionAction = segment.canKeepLocalVersion
            ? { await keepLocalVersion(for: segment.id) }
            : nil
        let restoreDeletedAction = segment.canRestoreDeletedSegment
            ? { await restoreDeletedSegment(for: segment.id) }
            : nil

        TimelineRowView(
            segment: segment,
            onApplyServerVersion: applyServerVersionAction,
            onKeepLocalVersion: keepLocalVersionAction,
            onRestoreDeletedSegment: restoreDeletedAction
        )
        .contentShape(Rectangle())
        .onTapGesture {
            inspectingSegment = segment
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if segment.isUserCreated {
                Button {
                    prepareManualSegmentForm(for: segment)
                    editingManualSegment = segment
                    isPresentingManualSegmentSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if segment.syncDisposition != .conflicted {
                Button(role: .destructive) {
                    Task {
                        await deleteSegment(for: segment.id)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func prepareManualSegmentForm() {
        editingManualSegment = nil
        let latestObservationTime = recentObservations.first?.timestamp ?? .now
        let earliestRecentObservationTime = recentObservations.prefix(20).last?.timestamp
            ?? latestObservationTime.addingTimeInterval(-30 * 60)

        manualSegmentEndTime = latestObservationTime
        manualSegmentStartTime = min(earliestRecentObservationTime, latestObservationTime)
        if manualSegmentStartTime >= manualSegmentEndTime {
            manualSegmentStartTime = latestObservationTime.addingTimeInterval(-15 * 60)
        }
        manualSegmentActivityClass = .walking
        manualSegmentLabel = ""
        manualSegmentDistanceMeters = ""
    }

    private func prepareManualSegmentForm(for segment: SegmentSnapshot) {
        manualSegmentStartTime = segment.startTime
        manualSegmentEndTime = segment.endTime
        manualSegmentActivityClass = segment.activityClass
        manualSegmentLabel = currentEditableLabel(for: segment)
        manualSegmentDistanceMeters = segment.distanceMeters.map { String(format: "%.0f", $0) } ?? ""
    }

    private func prepareRecentWorkoutSegmentForm(activityClass: ActivityClass) {
        editingManualSegment = nil
        let inferredWindow = inferredRecentWorkoutWindow(for: activityClass)
        manualSegmentStartTime = inferredWindow.startTime
        manualSegmentEndTime = inferredWindow.endTime
        manualSegmentActivityClass = activityClass
        manualSegmentLabel = ""
        manualSegmentDistanceMeters = ""
    }

    private func saveManualSegment() async {
        do {
            let writer = LocalUserSegmentWriter(modelContext: modelContext)
            if let editingManualSegment {
                try writer.updateSegment(
                    segmentID: editingManualSegment.id,
                    startTime: manualSegmentStartTime,
                    endTime: manualSegmentEndTime,
                    activityClass: manualSegmentActivityClass,
                    narrowerLabel: manualSegmentLabel,
                    distanceMeters: parseManualDistanceMeters()
                )
            } else {
                try writer.createSegment(
                    startTime: manualSegmentStartTime,
                    endTime: manualSegmentEndTime,
                    activityClass: manualSegmentActivityClass,
                    narrowerLabel: manualSegmentLabel,
                    distanceMeters: parseManualDistanceMeters()
                )
            }
            isPresentingManualSegmentSheet = false
            liveDraftStatusMessage = editingManualSegment == nil
                ? "Saved a user-marked \(manualSegmentActivityClass.displayName.lowercased()) segment."
                : "Updated that \(manualSegmentActivityClass.displayName.lowercased()) segment."
            editingManualSegment = nil
            refreshSyncActivity()
            await pushPendingSync()
        } catch {
            syncActivity.lastPushMessage = "Could not save that marked segment."
        }
    }

    private func parseManualDistanceMeters() -> Double? {
        let trimmed = manualSegmentDistanceMeters.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        return Double(trimmed.replacingOccurrences(of: ",", with: ""))
    }

    private func inferredRecentWorkoutWindow(for activityClass: ActivityClass) -> (startTime: Date, endTime: Date) {
        let latestObservationTime = recentObservations.first?.timestamp ?? .now
        let fallbackStartTime = latestObservationTime.addingTimeInterval(-45 * 60)
        let relevantObservations = recentObservations
            .filter { isRelevantRecentWorkoutObservation($0, activityClass: activityClass) }
            .sorted { $0.timestamp > $1.timestamp }

        guard let latestRelevantObservation = relevantObservations.first else {
            return (fallbackStartTime, latestObservationTime)
        }

        var earliestTime = intervalStart(for: latestRelevantObservation)
        var latestTime = intervalEnd(for: latestRelevantObservation)
        var previousTimestamp = latestRelevantObservation.timestamp

        for observation in relevantObservations.dropFirst() {
            let gap = previousTimestamp.timeIntervalSince(observation.timestamp)
            if gap > 10 * 60 {
                break
            }

            earliestTime = min(earliestTime, intervalStart(for: observation))
            latestTime = max(latestTime, intervalEnd(for: observation))
            previousTimestamp = observation.timestamp
        }

        return (earliestTime, latestTime)
    }

    private func isRelevantRecentWorkoutObservation(
        _ observation: ObservationRecord,
        activityClass: ActivityClass
    ) -> Bool {
        switch observation.sourceType {
        case .location:
            return true
        case .pedometer:
            return true
        case .motion:
            let values = payloadValues(from: observation.payload)
            switch activityClass {
            case .running:
                return values["running"] == "true"
            case .walking:
                return values["walking"] == "true"
            default:
                return true
            }
        default:
            return false
        }
    }

    private func intervalStart(for observation: ObservationRecord) -> Date {
        let values = payloadValues(from: observation.payload)
        if let startInterval = values["start"].flatMap(TimeInterval.init) {
            return Date(timeIntervalSince1970: startInterval)
        }

        return observation.timestamp
    }

    private func intervalEnd(for observation: ObservationRecord) -> Date {
        let values = payloadValues(from: observation.payload)
        if let endInterval = values["end"].flatMap(TimeInterval.init) {
            return Date(timeIntervalSince1970: endInterval)
        }

        return observation.timestamp
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

    private func refreshSyncActivity() {
        syncActivity.refresh(using: modelContext)
    }

    private func pushPendingSync() async {
        await syncActivity.pushPending(using: modelContext)
    }

    private func loadSegments() {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("[Timeline] Loading up to \(visibleSegmentLimit) recent segments.")
        var descriptor = FetchDescriptor<SegmentRecord>(
            sortBy: [SortDescriptor(\SegmentRecord.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = visibleSegmentLimit + 1
        let fetchedSegments = (try? modelContext.fetch(descriptor)) ?? []
        hasMoreSegments = fetchedSegments.count > visibleSegmentLimit
        segments = Array(fetchedSegments.prefix(visibleSegmentLimit))
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("[Timeline] Loaded \(segments.count) recent segments in \(String(format: "%.3f", elapsed))s. hasMore=\(hasMoreSegments)")
    }

    private func loadRecentObservations() {
        let startTime = CFAbsoluteTimeGetCurrent()
        var descriptor = FetchDescriptor<ObservationRecord>(
            sortBy: [SortDescriptor(\ObservationRecord.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 240
        recentObservations = (try? modelContext.fetch(descriptor)) ?? []
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("[Timeline] Loaded \(recentObservations.count) recent observations in \(String(format: "%.3f", elapsed))s.")
    }

    private func refreshRecentObservationsLoop() async {
        while Task.isCancelled == false {
            loadRecentObservations()
            try? await Task.sleep(for: .seconds(5))
        }
    }
}
