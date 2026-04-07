import SwiftData
import SwiftUI
import HealthKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var captureReadiness = CaptureReadinessStore()
    @State private var captureControl = CaptureControlStore()
    @State private var watchConnectivity = WatchConnectivityStore()
    @State private var healthBackfill = HealthBackfillStore()
    @State private var syncActivity = SyncActivityStore()
    @State private var presentedResumeReport: CaptureResumeReport?
    @State private var hasBackfilledSegmentMetrics = false

    var body: some View {
        TabView {
            TimelineView(syncActivity: syncActivity)
                .tabItem {
                    Label("Activity", systemImage: "figure.walk.motion")
                }

            SettingsView(
                captureReadiness: captureReadiness,
                captureControl: captureControl,
                onRefreshCaptureReadiness: refreshCaptureReadiness,
                onRequestLocationAuthorization: requestLocationAuthorization,
                onStartLocation: startLocationCapture,
                onStopLocation: stopLocationCapture,
                onStartMotion: startMotionCapture,
                onStopMotion: stopMotionCapture,
                onStartPedometer: startPedometerCapture,
                onStopPedometer: stopPedometerCapture,
                watchConnectivity: watchConnectivity,
                healthBackfill: healthBackfill,
                onRequestHealthAuthorization: requestHealthAuthorization,
                onBackfillRecentWatchHealth: backfillRecentWatchHealth
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }

            DataView(syncActivity: syncActivity)
                .tabItem {
                    Label("Data", systemImage: "tray.full")
                }
        }
        .task {
            configureCapture()
            presentedResumeReport = await captureControl.handleDidBecomeActive()
            await resumeCaptureIfNeeded()
            backfillSegmentMetrics()
            await refreshHealthBackfillIfNeeded()
            refreshCaptureReadiness()
            refreshSyncActivity()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    presentedResumeReport = await captureControl.handleDidBecomeActive()
                    await resumeCaptureIfNeeded()
                    await refreshHealthBackfillIfNeeded()
                    refreshSyncActivity()
                }
            } else if scenePhase == .background {
                captureControl.handleDidEnterBackground()
            }
        }
        .alert(
            presentedResumeReport?.title ?? "Capture Summary",
            isPresented: Binding(
                get: { presentedResumeReport != nil },
                set: { isPresented in
                    if isPresented == false {
                        presentedResumeReport = nil
                    }
                }
            ),
            actions: {
                Button("OK") {
                    presentedResumeReport = nil
                }
            },
            message: {
                Text(presentedResumeReport?.message ?? "")
            }
        )
    }

    private func configureCapture() {
        captureControl.configure(modelContext: modelContext)
        watchConnectivity.configure(modelContext: modelContext)
        healthBackfill.configure(modelContext: modelContext)
    }

    private func resumeCaptureIfNeeded() async {
        await captureControl.resumeIfNeeded()
        refreshCaptureReadiness()
    }

    private func refreshCaptureReadiness() {
        captureReadiness.refresh()
    }

    private func requestLocationAuthorization() async {
        await captureReadiness.requestLocationAuthorization()
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

    private func requestHealthAuthorization() async {
        await healthBackfill.requestAuthorization()
    }

    private func backfillRecentWatchHealth() async {
        await healthBackfill.backfillRecentWatchActivity()
    }

    private func refreshHealthBackfillIfNeeded() async {
        guard healthBackfill.hasRequestedAuthorization else {
            return
        }

        await healthBackfill.backfillRecentWatchActivity(hours: 12)
    }

    private func backfillSegmentMetrics() {
        guard hasBackfilledSegmentMetrics == false else {
            return
        }

        hasBackfilledSegmentMetrics = true
        let backfiller = LocalSegmentMetricBackfiller(modelContext: modelContext)
        try? backfiller.backfillMissingDistanceMetrics()
    }
}

#Preview {
    ContentView()
        .modelContainer(ModelContainer.blackbox)
}

@MainActor
@Observable
final class HealthBackfillStore {
    private enum Keys {
        static let authorizationRequested = "health_backfill.authorization_requested"
    }

    var isAvailable = HKHealthStore.isHealthDataAvailable()
    var hasRequestedAuthorization = UserDefaults.standard.bool(forKey: Keys.authorizationRequested)
    var lastBackfillAt: Date?
    var lastImportedObservationCount = 0
    var lastImportedStepSampleCount = 0
    var lastImportedDistanceSampleCount = 0
    var lastSkippedSampleCount = 0
    var statusNote: String?

    private let healthStore = HKHealthStore()
    private var recorder: LocalObservationRecorder?
    private var modelContext: ModelContext?

    var authorizationSummary: String {
        guard isAvailable else {
            return "Unavailable"
        }

        return hasRequestedAuthorization ? "Requested" : "Not Requested"
    }

    var lastBackfillSummary: String? {
        guard let lastBackfillAt else {
            return nil
        }

        return "\(lastBackfillAt.formatted(date: .omitted, time: .shortened)) • \(lastImportedObservationCount) observations"
    }

    var lastBreakdownSummary: String? {
        guard lastBackfillAt != nil else {
            return nil
        }

        return "\(lastImportedStepSampleCount) steps • \(lastImportedDistanceSampleCount) distance • \(lastSkippedSampleCount) skipped"
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        recorder = LocalObservationRecorder(modelContext: modelContext)

        guard isAvailable else {
            statusNote = "Health data is unavailable on this iPhone."
            return
        }

        if hasRequestedAuthorization {
            statusNote = "Health backfill can recover watch step and walking distance samples when direct watch capture misses them."
        } else {
            statusNote = "Authorize Health access to recover Apple Watch step and walking distance history on the iPhone."
        }
    }

    func requestAuthorization() async {
        guard isAvailable else {
            statusNote = "Health data is unavailable on this iPhone."
            return
        }

        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        let readTypes = Set([stepType, distanceType].compactMap { $0 })

        guard readTypes.isEmpty == false else {
            statusNote = "Health backfill types are unavailable on this iPhone."
            return
        }

        let result = await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                continuation.resume(returning: (success, error))
            }
        }

        if let error = result.1 {
            statusNote = "Health authorization failed: \(error.localizedDescription)"
            return
        }

        guard result.0 else {
            statusNote = "Health authorization was not granted."
            return
        }

        hasRequestedAuthorization = true
        UserDefaults.standard.set(true, forKey: Keys.authorizationRequested)
        statusNote = "Health backfill is authorized. Blackbox can now recover watch step and distance samples on the iPhone."
    }

    func backfillRecentWatchActivity(hours: Double = 24) async {
        let endDate = Date.now
        let startDate = endDate.addingTimeInterval(-(hours * 60 * 60))
        await backfill(from: startDate, to: endDate)
    }

    func backfill(from startDate: Date, to endDate: Date) async {
        guard isAvailable else {
            statusNote = "Health data is unavailable on this iPhone."
            return
        }

        guard hasRequestedAuthorization else {
            statusNote = "Authorize Health access before running watch activity backfill."
            return
        }

        guard let recorder, endDate > startDate else {
            return
        }

        let stepSamples = await quantitySamples(
            identifier: .stepCount,
            startDate: startDate,
            endDate: endDate
        )
        let distanceSamples = await quantitySamples(
            identifier: .distanceWalkingRunning,
            startDate: startDate,
            endDate: endDate
        )

        var skippedSampleCount = 0
        let stepInputs = stepSamples.compactMap { sample in
            makeObservationInput(
                for: sample,
                identifier: .stepCount,
                skippedSampleCount: &skippedSampleCount
            )
        }
        let distanceInputs = distanceSamples.compactMap { sample in
            makeObservationInput(
                for: sample,
                identifier: .distanceWalkingRunning,
                skippedSampleCount: &skippedSampleCount
            )
        }

        let inputs = (stepInputs + distanceInputs).sorted { $0.timestamp < $1.timestamp }

        do {
            if inputs.isEmpty == false {
                try recorder.record(inputs)
            }

            lastBackfillAt = .now
            lastImportedObservationCount = inputs.count
            lastImportedStepSampleCount = stepInputs.count
            lastImportedDistanceSampleCount = distanceInputs.count
            lastSkippedSampleCount = skippedSampleCount

            if inputs.isEmpty {
                statusNote = "Health backfill found no new watch step or distance samples in the selected window."
            } else {
                statusNote = "Recovered \(inputs.count) watch Health samples on the iPhone (\(stepInputs.count) steps, \(distanceInputs.count) distance)."
            }
        } catch {
            statusNote = "Failed to persist Health backfill samples."
        }
    }

    private func quantitySamples(
        identifier: HKQuantityTypeIdentifier,
        startDate: Date,
        endDate: Date
    ) async -> [HKQuantitySample] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate]
        )
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func makeObservationInput(
        for sample: HKQuantitySample,
        identifier: HKQuantityTypeIdentifier,
        skippedSampleCount: inout Int
    ) -> ObservationInput? {
        var components = [
            "start=\(sample.startDate.timeIntervalSince1970)",
            "end=\(sample.endDate.timeIntervalSince1970)",
            "historical=true",
            "origin=healthKitBackfill",
            "healthQuantity=\(identifier.rawValue)",
            "healthSourceDevice=\(inferredSourceDevice(sample).rawValue)",
        ]

        switch identifier {
        case .stepCount:
            let steps = Int(sample.quantity.doubleValue(for: .count()))
            guard steps > 0 else {
                return nil
            }
            components.append("steps=\(steps)")
        case .distanceWalkingRunning:
            let distanceMeters = sample.quantity.doubleValue(for: .meter())
            guard distanceMeters > 0 else {
                return nil
            }
            components.append("distance=\(distanceMeters)")
        default:
            return nil
        }

        if let productType = sample.sourceRevision.productType {
            components.append("healthProductType=\(productType)")
        }

        if let version = sample.sourceRevision.version {
            components.append("healthSourceVersion=\(version)")
        }

        components.append("healthBundle=\(sample.sourceRevision.source.bundleIdentifier)")

        return ObservationInput(
            id: sample.uuid,
            timestamp: sample.endDate,
            sourceDevice: inferredSourceDevice(sample),
            sourceType: .pedometer,
            payload: components.joined(separator: ";"),
            ingestedAt: .now
        )
    }

    private func inferredSourceDevice(_ sample: HKQuantitySample) -> ObservationSourceDevice {
        if let productType = sample.sourceRevision.productType?.lowercased(), productType.hasPrefix("watch") {
            return .watch
        }

        if let model = sample.device?.model?.lowercased(), model.contains("watch") {
            return .watch
        }

        return .iPhone
    }
}
