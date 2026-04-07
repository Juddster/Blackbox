import HealthKit
import CoreLocation
import CryptoKit
import SwiftData
import SwiftUI

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
                onBackfillRecentWatchHealth: backfillRecentWatchHealth,
                onForceFullHealthBackfill: forceFullHealthBackfill
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
        await healthBackfill.backfillSinceLastRequest()
    }

    private func forceFullHealthBackfill() async {
        await healthBackfill.forceFullBackfill()
    }

    private func refreshHealthBackfillIfNeeded() async {
        guard healthBackfill.hasRequestedAuthorization else {
            return
        }

        await healthBackfill.backfillSinceLastRequest()
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
        static let lastBackfillCursorTimeInterval = "health_backfill.last_backfill_cursor_time_interval"
    }

    private struct RouteImportResult {
        let routeSeriesCount: Int
        let routePointCount: Int
        let importedObservationCount: Int
    }

    private let persistenceBatchSize = 2_000

    var isAvailable = HKHealthStore.isHealthDataAvailable()
    var hasRequestedAuthorization = UserDefaults.standard.bool(forKey: Keys.authorizationRequested)
    var lastBackfillAt: Date?
    var lastBackfillCursor: Date? = {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Keys.lastBackfillCursorTimeInterval) != nil else {
            return nil
        }

        return Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.lastBackfillCursorTimeInterval))
    }()
    var lastImportedObservationCount = 0
    var lastImportedStepSampleCount = 0
    var lastImportedDistanceSampleCount = 0
    var lastImportedRoutePointCount = 0
    var lastImportedHeartRateSampleCount = 0
    var lastSkippedSampleCount = 0
    var isRunning = false
    var lastRequestedStartDate: Date?
    var lastRequestedEndDate: Date?
    var lastFoundWorkoutCount = 0
    var lastFoundStepSampleCount = 0
    var lastFoundDistanceSampleCount = 0
    var lastFoundRouteCount = 0
    var lastFoundRoutePointCount = 0
    var lastFoundHeartRateSampleCount = 0
    var statusNote: String?

    private let healthStore = HKHealthStore()
    private var recorder: LocalObservationRecorder?
    private var modelContext: ModelContext?

    private nonisolated static func debugLog(_ message: String) {
        print("[HealthBackfill] \(message)")
    }

    private func log(_ message: String) {
        Self.debugLog(message)
    }

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

        if let lastBackfillCursor {
            return "\(lastBackfillAt.formatted(date: .omitted, time: .shortened)) • \(lastImportedObservationCount) observations • cursor \(lastBackfillCursor.formatted(date: .abbreviated, time: .shortened))"
        }

        return "\(lastBackfillAt.formatted(date: .omitted, time: .shortened)) • \(lastImportedObservationCount) observations"
    }

    var lastBreakdownSummary: String? {
        guard lastBackfillAt != nil else {
            return nil
        }

        return "\(lastImportedStepSampleCount) steps • \(lastImportedDistanceSampleCount) distance • \(lastImportedRoutePointCount) route • \(lastImportedHeartRateSampleCount) heart rate • \(lastSkippedSampleCount) skipped"
    }

    var runStateSummary: String {
        isRunning ? "Running" : "Idle"
    }

    var lastQueryWindowSummary: String? {
        guard let lastRequestedStartDate, let lastRequestedEndDate else {
            return nil
        }

        return "\(lastRequestedStartDate.formatted(date: .abbreviated, time: .shortened)) → \(lastRequestedEndDate.formatted(date: .abbreviated, time: .shortened))"
    }

    var lastFoundSummary: String? {
        guard lastRequestedEndDate != nil else {
            return nil
        }

        return "\(lastFoundWorkoutCount) workouts • \(lastFoundStepSampleCount) steps • \(lastFoundDistanceSampleCount) distance • \(lastFoundRouteCount) routes • \(lastFoundRoutePointCount) route points • \(lastFoundHeartRateSampleCount) heart rate"
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        recorder = LocalObservationRecorder(modelContext: modelContext)

        guard isAvailable else {
            statusNote = "Health data is unavailable on this iPhone."
            return
        }

        if hasRequestedAuthorization {
            statusNote = "Health backfill can recover step, distance, route, and heart-rate history from Apple Health on the iPhone."
        } else {
            statusNote = "Authorize Health access to recover workout and activity history from Apple Health on the iPhone."
        }
    }

    func requestAuthorization() async {
        guard isAvailable else {
            statusNote = "Health data is unavailable on this iPhone."
            log("Authorization skipped because Health data is unavailable.")
            return
        }

        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let workoutType = HKObjectType.workoutType()
        let workoutRouteType = HKSeriesType.workoutRoute()
        let readTypes = Set([stepType, distanceType, heartRateType, workoutType, workoutRouteType].compactMap { $0 })

        guard readTypes.isEmpty == false else {
            statusNote = "Health backfill types are unavailable on this iPhone."
            log("Authorization failed because required Health types were unavailable.")
            return
        }

        log("Requesting Health authorization for \(readTypes.count) types.")

        let result = await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                continuation.resume(returning: (success, error))
            }
        }

        if let error = result.1 {
            statusNote = "Health authorization failed: \(error.localizedDescription)"
            log("Authorization error: \(error.localizedDescription)")
            return
        }

        guard result.0 else {
            statusNote = "Health authorization was not granted."
            log("Authorization was denied.")
            return
        }

        hasRequestedAuthorization = true
        UserDefaults.standard.set(true, forKey: Keys.authorizationRequested)
        statusNote = "Health backfill is authorized. Blackbox can now recover step, distance, route, and heart-rate samples on the iPhone."
        log("Authorization granted.")
    }

    func backfillSinceLastRequest() async {
        let endDate = Date.now
        let startDate = resolvedBackfillStartDate(endDate: endDate)
        await backfill(from: startDate, to: endDate)
    }

    func forceFullBackfill() async {
        await backfill(from: healthStore.earliestPermittedSampleDate(), to: .now)
    }

    func backfill(from startDate: Date, to endDate: Date) async {
        guard isAvailable else {
            statusNote = "Health data is unavailable on this iPhone."
            log("Backfill skipped because Health data is unavailable.")
            return
        }

        guard hasRequestedAuthorization else {
            statusNote = "Authorize Health access before running watch activity backfill."
            log("Backfill skipped because authorization has not been requested.")
            return
        }

        guard let recorder, endDate > startDate else {
            log("Backfill skipped because recorder was missing or the window was invalid.")
            return
        }

        isRunning = true
        lastRequestedStartDate = startDate
        lastRequestedEndDate = endDate
        statusNote = "Running Health backfill from \(startDate.formatted(date: .abbreviated, time: .shortened)) to \(endDate.formatted(date: .abbreviated, time: .shortened))."
        log("Starting backfill from \(startDate.ISO8601Format()) to \(endDate.ISO8601Format()).")
        defer {
            isRunning = false
            log("Backfill finished.")
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
        let workouts = await workouts(startDate: startDate, endDate: endDate)
        var skippedSampleCount = 0

        do {
            let importedStepCount = try persistQuantitySamples(
                stepSamples,
                identifier: .stepCount,
                recorder: recorder,
                skippedSampleCount: &skippedSampleCount
            )
            let importedDistanceCount = try persistQuantitySamples(
                distanceSamples,
                identifier: .distanceWalkingRunning,
                recorder: recorder,
                skippedSampleCount: &skippedSampleCount
            )
            let routeImport = try await importWorkoutRoutes(for: workouts, recorder: recorder)
            let heartRateImport = try await importWorkoutHeartRates(for: workouts, recorder: recorder)
            let importedObservationCount = importedStepCount + importedDistanceCount + routeImport.importedObservationCount + heartRateImport

            log("Raw query counts: \(stepSamples.count) step samples, \(distanceSamples.count) distance samples, \(workouts.count) workouts, \(routeImport.routeSeriesCount) route series.")
            log("Imported observations: \(importedStepCount) step, \(importedDistanceCount) distance, \(routeImport.importedObservationCount) route, \(heartRateImport) heart rate.")

            lastFoundWorkoutCount = workouts.count
            lastFoundStepSampleCount = stepSamples.count
            lastFoundDistanceSampleCount = distanceSamples.count
            lastFoundRouteCount = routeImport.routeSeriesCount
            lastFoundRoutePointCount = routeImport.routePointCount
            lastFoundHeartRateSampleCount = heartRateImport

            lastBackfillAt = .now
            lastBackfillCursor = endDate
            lastImportedObservationCount = importedObservationCount
            lastImportedStepSampleCount = importedStepCount
            lastImportedDistanceSampleCount = importedDistanceCount
            lastImportedRoutePointCount = routeImport.importedObservationCount
            lastImportedHeartRateSampleCount = heartRateImport
            lastSkippedSampleCount = skippedSampleCount
            UserDefaults.standard.set(endDate.timeIntervalSinceReferenceDate, forKey: Keys.lastBackfillCursorTimeInterval)

            if importedObservationCount == 0 {
                statusNote = "Health backfill found no new step, distance, route, or heart-rate samples between \(startDate.formatted(date: .abbreviated, time: .shortened)) and \(endDate.formatted(date: .abbreviated, time: .shortened))."
                log("Backfill completed with no importable samples.")
            } else {
                statusNote = "Recovered \(importedObservationCount) Health samples on the iPhone (\(importedStepCount) steps, \(importedDistanceCount) distance, \(routeImport.importedObservationCount) route, \(heartRateImport) heart rate) between \(startDate.formatted(date: .abbreviated, time: .shortened)) and \(endDate.formatted(date: .abbreviated, time: .shortened))."
                log("Backfill persisted successfully.")
            }
        } catch {
            statusNote = "Failed to persist Health backfill samples."
            log("Persistence failed: \(error.localizedDescription)")
        }
    }

    private func resolvedBackfillStartDate(endDate: Date) -> Date {
        if let lastBackfillCursor, lastBackfillCursor < endDate {
            return lastBackfillCursor
        }

        return healthStore.earliestPermittedSampleDate()
    }

    private func quantitySamples(
        identifier: HKQuantityTypeIdentifier,
        startDate: Date,
        endDate: Date,
        additionalPredicate: NSPredicate? = nil
    ) async -> [HKQuantitySample] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate]
        )
        let predicate = compoundPredicate(datePredicate, additionalPredicate)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                guard error == nil else {
                    Self.debugLog("Quantity query for \(identifier.rawValue) failed: \(error?.localizedDescription ?? "unknown error")")
                    continuation.resume(returning: [])
                    return
                }

                Self.debugLog("Quantity query for \(identifier.rawValue) returned \((samples as? [HKQuantitySample])?.count ?? 0) samples.")
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func workouts(startDate: Date, endDate: Date) async -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: []
        )
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                guard error == nil else {
                    Self.debugLog("Workout query failed: \(error?.localizedDescription ?? "unknown error")")
                    continuation.resume(returning: [])
                    return
                }

                Self.debugLog("Workout query returned \((samples as? [HKWorkout])?.count ?? 0) workouts.")
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func importWorkoutRoutes(for workouts: [HKWorkout], recorder: LocalObservationRecorder) async throws -> RouteImportResult {
        var routeSeriesCount = 0
        var routePointCount = 0
        var importedObservationCount = 0
        for (index, workout) in workouts.enumerated() {
            log("Processing routes for workout \(index + 1)/\(workouts.count) \(workout.uuid.uuidString) [\(workout.startDate.ISO8601Format()) - \(workout.endDate.ISO8601Format())].")
            let routes = await workoutRoutes(for: workout)
            routeSeriesCount += routes.count
            log("Workout \(workout.uuid.uuidString) has \(routes.count) route series.")
            for route in routes {
                let locations = await routeLocations(for: route)
                routePointCount += locations.count
                log("Route \(route.uuid.uuidString) returned \(locations.count) locations.")
                let inputs = locations.compactMap { location in
                    makeRouteObservationInput(for: location, route: route, workout: workout)
                }
                importedObservationCount += try persistObservations(inputs, recorder: recorder, label: "route \(route.uuid.uuidString)")
            }
        }

        return RouteImportResult(
            routeSeriesCount: routeSeriesCount,
            routePointCount: routePointCount,
            importedObservationCount: importedObservationCount
        )
    }

    private func importWorkoutHeartRates(for workouts: [HKWorkout], recorder: LocalObservationRecorder) async throws -> Int {
        var importedObservationCount = 0
        for (index, workout) in workouts.enumerated() {
            log("Processing heart rate for workout \(index + 1)/\(workouts.count) \(workout.uuid.uuidString).")
            let predicate = HKQuery.predicateForObjects(from: workout)
            let samples = await quantitySamples(
                identifier: .heartRate,
                startDate: workout.startDate,
                endDate: workout.endDate,
                additionalPredicate: predicate
            )
            log("Workout \(workout.uuid.uuidString) returned \(samples.count) heart-rate samples.")

            let inputs = samples.compactMap { sample in
                makeHeartRateObservationInput(for: sample, workout: workout)
            }
            importedObservationCount += try persistObservations(inputs, recorder: recorder, label: "heart rate \(workout.uuid.uuidString)")
        }

        return importedObservationCount
    }

    private func persistQuantitySamples(
        _ samples: [HKQuantitySample],
        identifier: HKQuantityTypeIdentifier,
        recorder: LocalObservationRecorder,
        skippedSampleCount: inout Int
    ) throws -> Int {
        var importedObservationCount = 0

        for (chunkIndex, chunk) in samples.chunked(into: persistenceBatchSize).enumerated() {
            let inputs = chunk.compactMap { sample in
                makeObservationInput(
                    for: sample,
                    identifier: identifier,
                    skippedSampleCount: &skippedSampleCount
                )
            }
            importedObservationCount += try persistObservations(
                inputs,
                recorder: recorder,
                label: "\(identifier.rawValue) chunk \(chunkIndex + 1)"
            )
        }

        return importedObservationCount
    }

    private func persistObservations(
        _ inputs: [ObservationInput],
        recorder: LocalObservationRecorder,
        label: String
    ) throws -> Int {
        guard inputs.isEmpty == false else {
            return 0
        }

        var persistedCount = 0
        for chunk in inputs.chunked(into: persistenceBatchSize) {
            try recorder.record(chunk)
            persistedCount += chunk.count
            log("Persisted \(chunk.count) observations for \(label) (\(persistedCount) total).")
        }

        return persistedCount
    }

    private func workoutRoutes(for workout: HKWorkout) async -> [HKWorkoutRoute] {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                guard error == nil else {
                    Self.debugLog("Workout route query for workout \(workout.uuid.uuidString) failed: \(error?.localizedDescription ?? "unknown error")")
                    continuation.resume(returning: [])
                    return
                }

                Self.debugLog("Workout route query for workout \(workout.uuid.uuidString) returned \((samples as? [HKWorkoutRoute])?.count ?? 0) series.")
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func routeLocations(for route: HKWorkoutRoute) async -> [CLLocation] {
        await withCheckedContinuation { continuation in
            var collected = [CLLocation]()
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let locations {
                    collected.append(contentsOf: locations)
                    Self.debugLog("Route \(route.uuid.uuidString) streamed \(locations.count) locations (\(collected.count) total).")
                }

                if error != nil || done {
                    if let error {
                        Self.debugLog("Route \(route.uuid.uuidString) failed: \(error.localizedDescription)")
                    } else {
                        Self.debugLog("Route \(route.uuid.uuidString) completed with \(collected.count) locations.")
                    }
                    continuation.resume(returning: error == nil ? collected : [])
                }
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

        components.append(contentsOf: metadataComponents(for: sample))

        return ObservationInput(
            id: sample.uuid,
            timestamp: sample.endDate,
            sourceDevice: inferredSourceDevice(sample),
            sourceType: .pedometer,
            payload: components.joined(separator: ";"),
            ingestedAt: .now
        )
    }

    private func makeRouteObservationInput(
        for location: CLLocation,
        route: HKWorkoutRoute,
        workout: HKWorkout
    ) -> ObservationInput? {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            return nil
        }

        let sample = route as HKSample
        var components = [
            "lat=\(location.coordinate.latitude)",
            "lon=\(location.coordinate.longitude)",
            "alt=\(location.altitude)",
            "speed=\(location.speed)",
            "course=\(location.course)",
            "hAcc=\(location.horizontalAccuracy)",
            "vAcc=\(location.verticalAccuracy)",
            "historical=true",
            "origin=healthKitBackfill",
            "healthQuantity=workoutRoute",
            "healthSourceDevice=\(inferredSourceDevice(sample).rawValue)",
            "healthWorkoutUUID=\(workout.uuid.uuidString)",
            "healthRouteUUID=\(route.uuid.uuidString)",
        ]
        components.append(contentsOf: metadataComponents(for: sample))

        return ObservationInput(
            id: deterministicUUID(
                namespace: "route:\(route.uuid.uuidString):\(location.timestamp.timeIntervalSince1970):\(location.coordinate.latitude):\(location.coordinate.longitude)"
            ),
            timestamp: location.timestamp,
            sourceDevice: inferredSourceDevice(sample),
            sourceType: .location,
            payload: components.joined(separator: ";"),
            qualityHint: location.horizontalAccuracy > 100 ? "degraded-horizontal-accuracy" : nil,
            ingestedAt: .now
        )
    }

    private func makeHeartRateObservationInput(
        for sample: HKQuantitySample,
        workout: HKWorkout
    ) -> ObservationInput? {
        let beatsPerMinute = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        guard beatsPerMinute > 0 else {
            return nil
        }

        var components = [
            "start=\(sample.startDate.timeIntervalSince1970)",
            "end=\(sample.endDate.timeIntervalSince1970)",
            "bpm=\(beatsPerMinute)",
            "historical=true",
            "origin=healthKitBackfill",
            "healthQuantity=\(HKQuantityTypeIdentifier.heartRate.rawValue)",
            "healthSourceDevice=\(inferredSourceDevice(sample).rawValue)",
            "healthWorkoutUUID=\(workout.uuid.uuidString)",
        ]
        components.append(contentsOf: metadataComponents(for: sample))

        return ObservationInput(
            id: sample.uuid,
            timestamp: sample.endDate,
            sourceDevice: inferredSourceDevice(sample),
            sourceType: .heartRate,
            payload: components.joined(separator: ";"),
            ingestedAt: .now
        )
    }

    private func inferredSourceDevice(_ sample: HKSample) -> ObservationSourceDevice {
        if let productType = sample.sourceRevision.productType?.lowercased(), productType.hasPrefix("watch") {
            return .watch
        }

        if let model = sample.device?.model?.lowercased(), model.contains("watch") {
            return .watch
        }

        return .iPhone
    }

    private func metadataComponents(for sample: HKSample) -> [String] {
        var components = [String]()

        if let productType = sample.sourceRevision.productType {
            components.append("healthProductType=\(productType)")
        }

        if let version = sample.sourceRevision.version {
            components.append("healthSourceVersion=\(version)")
        }

        components.append("healthBundle=\(sample.sourceRevision.source.bundleIdentifier)")
        return components
    }

    private func compoundPredicate(_ predicates: NSPredicate?...) -> NSPredicate? {
        let resolvedPredicates = predicates.compactMap { $0 }
        guard resolvedPredicates.isEmpty == false else {
            return nil
        }

        if resolvedPredicates.count == 1 {
            return resolvedPredicates[0]
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: resolvedPredicates)
    }

    private func deterministicUUID(namespace: String) -> UUID {
        let digest = SHA256.hash(data: Data(namespace.utf8))
        let bytes = Array(digest)
        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, isEmpty == false else {
            return isEmpty ? [] : [self]
        }

        var chunks = [[Element]]()
        chunks.reserveCapacity((count + size - 1) / size)

        var startIndex = 0
        while startIndex < count {
            let endIndex = Swift.min(startIndex + size, count)
            chunks.append(Array(self[startIndex..<endIndex]))
            startIndex = endIndex
        }

        return chunks
    }
}
