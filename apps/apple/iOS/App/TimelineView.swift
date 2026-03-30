import SwiftData
import SwiftUI

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    let syncActivity: SyncActivityStore

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
            SortDescriptor(\SegmentRecord.startTime, order: .reverse),
        ],
        animation: .snappy
    )
    private var segments: [SegmentRecord]

    @Query(
        sort: [
            SortDescriptor(\ObservationRecord.timestamp, order: .reverse),
        ],
        animation: .snappy
    )
    private var observations: [ObservationRecord]

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
            SegmentMapDetailView(
                segment: segment,
                observations: segmentObservations(for: segment)
            )
        }
    }

    private var groupedSegments: [TimelineDayGroup] {
        TimelineProjection.groups(from: segments)
    }

    private var liveDraftSegment: LiveDraftSegmentSnapshot? {
        LiveDraftSegmentProjection.make(from: observations)
    }

    private var observationCoverageDescription: String? {
        guard
            let newestObservation = observations.first?.timestamp,
            let oldestObservation = observations.last?.timestamp
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

    private func prepareRecentWorkoutSegmentForm(activityClass: ActivityClass) {
        let latestObservationTime = observations.first?.timestamp ?? .now
        let earliestRecentObservationTime = observations.prefix(80).last?.timestamp
            ?? latestObservationTime.addingTimeInterval(-90 * 60)

        manualSegmentEndTime = latestObservationTime
        manualSegmentStartTime = min(earliestRecentObservationTime, latestObservationTime)
        if manualSegmentStartTime >= manualSegmentEndTime {
            manualSegmentStartTime = latestObservationTime.addingTimeInterval(-45 * 60)
        }
        manualSegmentActivityClass = activityClass
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

    private func refreshSyncActivity() {
        syncActivity.refresh(using: modelContext)
    }

    private func pushPendingSync() async {
        await syncActivity.pushPending(using: modelContext)
    }
}
