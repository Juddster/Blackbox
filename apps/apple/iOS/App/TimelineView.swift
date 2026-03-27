import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var captureReadiness = CaptureReadinessStore()
    @State private var captureControl = CaptureControlStore()
    @State private var syncActivity = SyncActivityStore()
    @State private var liveDraftStatusMessage: String?
    @State private var editingSegment: SegmentSnapshot?
    @State private var inspectingSegment: SegmentSnapshot?
    @State private var editedActivityLabel = ""
    @State private var isPresentingManualSegmentSheet = false
    @State private var manualSegmentStartTime = Date.now.addingTimeInterval(-30 * 60)
    @State private var manualSegmentEndTime = Date.now
    @State private var manualSegmentActivityClass: ActivityClass = .walking
    @State private var manualSegmentLabel = ""
    @State private var manualSegmentDistanceMeters = ""

    @Query(
        sort: [
            SortDescriptor(\SegmentRecord.startTime, order: .reverse)
        ],
        animation: .snappy
    )
    private var segments: [SegmentRecord]

    @Query(
        sort: [
            SortDescriptor(\ObservationRecord.timestamp, order: .reverse)
        ],
        animation: .snappy
    )
    private var observations: [ObservationRecord]

    var body: some View {
        NavigationStack {
            List {
                TimelineSummarySection(summary: summary)
                CaptureStatusSection(
                    statuses: captureReadiness.statuses,
                    onRefresh: refreshCaptureReadiness,
                    onRequestLocation: requestLocationAuthorization
                )
                CaptureControlSection(
                    isLocationCapturing: captureControl.isLocationCapturing,
                    isMotionCapturing: captureControl.isMotionCapturing,
                    isPedometerCapturing: captureControl.isPedometerCapturing,
                    statusMessage: captureControl.statusMessage,
                    gapNotice: captureControl.gapNotice,
                    onStartLocation: startLocationCapture,
                    onStopLocation: stopLocationCapture,
                    onStartMotion: startMotionCapture,
                    onStopMotion: stopMotionCapture,
                    onStartPedometer: startPedometerCapture,
                    onStopPedometer: stopPedometerCapture
                )
                LiveDraftSegmentSection(
                    draft: liveDraftSegment,
                    statusMessage: liveDraftStatusMessage,
                    onPersistDraft: persistLiveDraft
                )
                RecentObservationsSection(observations: recentObservations)
                SyncStatusSection(
                    pendingCount: syncActivity.pendingCount,
                    conflictedCount: syncActivity.conflictedCount,
                    conflicts: syncActivity.conflicts,
                    isSyncing: syncActivity.isSyncing,
                    lastPushMessage: syncActivity.lastPushMessage,
                    lastSyncAt: syncActivity.lastSyncAt,
                    onPushPending: pushPendingSync
                )

                if groupedSegments.isEmpty {
                    Section("Timeline") {
                        Text("No saved real timeline segments yet. Recent captured observations appear above, and current inferred activity can be saved into the timeline.")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(groupedSegments) { group in
                    Section(group.title) {
                        ForEach(group.segments) { segment in
                            TimelineRowView(
                                segment: segment,
                                onApplyServerVersion: segment.canApplyServerVersion
                                    ? { await applyServerVersion(for: segment.id) }
                                    : nil,
                                onKeepLocalVersion: segment.canKeepLocalVersion
                                    ? { await keepLocalVersion(for: segment.id) }
                                    : nil,
                                onRestoreDeletedSegment: segment.canRestoreDeletedSegment
                                    ? { await restoreDeletedSegment(for: segment.id) }
                                    : nil
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                inspectingSegment = segment
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingSegment = segment
                                    editedActivityLabel = currentEditableLabel(for: segment)
                                } label: {
                                    Label("Label", systemImage: "pencil")
                                }
                                .tint(.blue)
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
                    }
                }
            }
            .navigationTitle("Blackbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prepareManualSegmentForm()
                        isPresentingManualSegmentSheet = true
                    } label: {
                        Label("Mark Segment", systemImage: "plus")
                    }
                }
            }
        }
        .task {
            configureCapture()
            await captureControl.handleDidBecomeActive()
            await resumeCaptureIfNeeded()
            refreshCaptureReadiness()
            refreshSyncActivity()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    await captureControl.handleDidBecomeActive()
                    await resumeCaptureIfNeeded()
                }
            } else if scenePhase == .background {
                captureControl.handleDidEnterBackground()
            }
        }
        .sheet(item: $editingSegment) { segment in
            NavigationStack {
                Form {
                    Section("Activity Label") {
                        TextField("train, bus, stair climbing...", text: $editedActivityLabel)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()

                        Text("Leave blank to clear the narrower user-selected label and fall back to the broad visible class.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(segment.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingSegment = nil
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await saveEditedActivityLabel()
                            }
                        }
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

                        Text("Use the broad class for baseline classification and the optional narrower label for what you know happened in that exact window.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Known Metrics") {
                        TextField("Distance meters (optional)", text: $manualSegmentDistanceMeters)
                            .keyboardType(.decimalPad)

                        Text("Add metrics you already know from another source, such as a workout distance, while keeping the raw captured observations unchanged.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let observationCoverageDescription {
                        Section("Recorded Evidence") {
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
            NavigationStack {
                List {
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

                    Section("Recorded Evidence") {
                        ForEach(observationSummaryRows(for: segment), id: \.label) { row in
                            LabeledContent(row.label, value: "\(row.count)")
                        }

                        if segmentObservations(for: segment).isEmpty {
                            Text("No local observations fall inside this marked time window yet.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Observations In Window") {
                        let snapshots = observationSnapshots(for: segment)
                        if snapshots.isEmpty {
                            Text("No local observations available for replay in this window.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshots) { observation in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(observation.title)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(observation.timestamp.formatted(date: .omitted, time: .standard))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(observation.detail)
                                        .font(.subheadline)

                                    if let qualityHint = observation.qualityHint {
                                        Text(qualityHint)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle("Segment Evidence")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            inspectingSegment = nil
                        }
                    }
                }
            }
        }
    }

    private var summary: TimelineSummary {
        TimelineProjection.summary(
            segmentCount: TimelineProjection.visibleSegmentCount(from: segments),
            observationCount: observations.count,
            syncSummary: SyncProjection.summary(from: segments)
        )
    }

    private var groupedSegments: [TimelineDayGroup] {
        TimelineProjection.groups(from: segments)
    }

    private var recentObservations: [ObservationSnapshot] {
        ObservationProjection.recent(from: observations)
    }

    private var liveDraftSegment: LiveDraftSegmentSnapshot? {
        LiveDraftSegmentProjection.make(from: observations)
    }

    private var observationCoverageDescription: String? {
        guard
            let newestObservation = observations.first?.timestamp,
            let oldestObservation = observations.last?.timestamp
        else {
            return "No recorded observations yet. You can still mark a segment manually, but there is no captured evidence in local storage yet."
        }

        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return "Local observations currently cover \(formatter.string(from: oldestObservation, to: newestObservation))."
    }

    private func refreshCaptureReadiness() {
        captureReadiness.refresh()
    }

    private func requestLocationAuthorization() async {
        await captureReadiness.requestLocationAuthorization()
    }

    private func configureCapture() {
        captureControl.configure(modelContext: modelContext)
    }

    private func resumeCaptureIfNeeded() async {
        await captureControl.resumeIfNeeded()
        refreshCaptureReadiness()
    }

    private func startLocationCapture() async {
        await captureControl.startLocationCapture()
        refreshCaptureReadiness()
    }

    private func stopLocationCapture() {
        captureControl.stopLocationCapture()
    }

    private func startMotionCapture() async {
        await captureControl.startMotionCapture()
        refreshCaptureReadiness()
    }

    private func stopMotionCapture() {
        captureControl.stopMotionCapture()
    }

    private func startPedometerCapture() async {
        await captureControl.startPedometerCapture()
        refreshCaptureReadiness()
    }

    private func stopPedometerCapture() {
        captureControl.stopPedometerCapture()
    }

    private func refreshSyncActivity() {
        syncActivity.refresh(using: modelContext)
    }

    private func pushPendingSync() async {
        await syncActivity.pushPending(using: modelContext)
    }

    private func persistLiveDraft() async {
        guard let liveDraftSegment else {
            liveDraftStatusMessage = "No live draft available to save."
            return
        }

        do {
            let writer = LocalDraftSegmentWriter(modelContext: modelContext)
            let result = try writer.upsert(from: liveDraftSegment)
            liveDraftStatusMessage = switch result.action {
            case .created:
                "Started a new timeline segment for \(result.segment.title.lowercased())."
            case .updated:
                "Updated the current timeline segment for \(result.segment.title.lowercased())."
            }
            refreshSyncActivity()
            await pushPendingSync()
        } catch {
            liveDraftStatusMessage = "Could not save draft to timeline."
        }
    }

    private func applyServerVersion(for segmentID: UUID) async {
        do {
            let coordinator = LocalSyncCoordinator()
            try coordinator.applyStoredServerEnvelope(
                for: segmentID,
                modelContext: modelContext
            )
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
            refreshSyncActivity()
            await pushPendingSync()
        } catch {
            syncActivity.lastPushMessage = "Could not delete that segment."
        }
    }

    private func saveEditedActivityLabel() async {
        guard let segment = editingSegment else {
            return
        }

        do {
            let editor = LocalSegmentInterpretationEditor(modelContext: modelContext)
            try editor.updateUserSelectedClass(
                for: segment.id,
                label: editedActivityLabel
            )
            editingSegment = nil
            refreshSyncActivity()
            await pushPendingSync()
        } catch {
            syncActivity.lastPushMessage = "Could not update that activity label."
        }
    }

    private func currentEditableLabel(for segment: SegmentSnapshot) -> String {
        segment.visibleClassLabel == nil ? "" : segment.activityLabel
    }

    private func prepareManualSegmentForm() {
        let latestObservationTime = observations.first?.timestamp ?? .now
        let earliestRecentObservationTime = observations.prefix(20).last?.timestamp
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

    private func saveManualSegment() async {
        do {
            let writer = LocalUserSegmentWriter(modelContext: modelContext)
            try writer.createSegment(
                startTime: manualSegmentStartTime,
                endTime: manualSegmentEndTime,
                activityClass: manualSegmentActivityClass,
                narrowerLabel: manualSegmentLabel,
                distanceMeters: parseManualDistanceMeters()
            )
            isPresentingManualSegmentSheet = false
            liveDraftStatusMessage = "Saved a user-marked \(manualSegmentActivityClass.displayName.lowercased()) segment."
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

    private func segmentObservations(for segment: SegmentSnapshot) -> [ObservationRecord] {
        observations.filter { observation in
            observation.timestamp >= segment.startTime && observation.timestamp <= segment.endTime
        }
    }

    private func observationSnapshots(for segment: SegmentSnapshot) -> [ObservationSnapshot] {
        ObservationProjection.recent(from: segmentObservations(for: segment), limit: 50)
    }

    private func observationSummaryRows(for segment: SegmentSnapshot) -> [(label: String, count: Int)] {
        let groupedCounts = Dictionary(grouping: segmentObservations(for: segment), by: \.sourceType)
            .map { sourceType, observations in
                (label: sourceTypeLabel(sourceType), count: observations.count)
            }
            .sorted { $0.label < $1.label }

        return groupedCounts.isEmpty ? [("Total", 0)] : [("Total", segmentObservations(for: segment).count)] + groupedCounts
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
