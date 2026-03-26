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
    @State private var editedActivityLabel = ""

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
                    warningMessage: captureControl.warningMessage,
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
        }
        .task {
            configureCapture()
            await resumeCaptureIfNeeded()
            refreshCaptureReadiness()
            refreshSyncActivity()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    await resumeCaptureIfNeeded()
                }
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
}
