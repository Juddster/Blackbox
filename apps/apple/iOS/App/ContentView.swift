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
        statusNote = "Health backfill is authorized. Blackbox can now recover step, distance, route, and heart-rate samples on the iPhone."
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
            return
        }

        guard hasRequestedAuthorization else {
            statusNote = "Authorize Health access before running watch activity backfill."
            return
        }

        guard let recorder, endDate > startDate else {
            return
        }

        isRunning = true
        lastRequestedStartDate = startDate
        lastRequestedEndDate = endDate
        statusNote = "Running Health backfill from \(startDate.formatted(date: .abbreviated, time: .shortened)) to \(endDate.formatted(date: .abbreviated, time: .shortened))."
        defer {
            isRunning = false
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
        let routeSeriesCount = await workoutRouteSeriesCount(for: workouts)

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
        let routeInputs = await workoutRouteInputs(for: workouts)
        let heartRateInputs = await workoutHeartRateInputs(for: workouts)

        lastFoundWorkoutCount = workouts.count
        lastFoundStepSampleCount = stepSamples.count
        lastFoundDistanceSampleCount = distanceSamples.count
        lastFoundRouteCount = routeSeriesCount
        lastFoundRoutePointCount = routeInputs.count
        lastFoundHeartRateSampleCount = heartRateInputs.count

        let inputs = (stepInputs + distanceInputs + routeInputs + heartRateInputs).sorted { $0.timestamp < $1.timestamp }

        do {
            if inputs.isEmpty == false {
                try recorder.record(inputs)
            }

            lastBackfillAt = .now
            lastBackfillCursor = endDate
            lastImportedObservationCount = inputs.count
            lastImportedStepSampleCount = stepInputs.count
            lastImportedDistanceSampleCount = distanceInputs.count
            lastImportedRoutePointCount = routeInputs.count
            lastImportedHeartRateSampleCount = heartRateInputs.count
            lastSkippedSampleCount = skippedSampleCount
            UserDefaults.standard.set(endDate.timeIntervalSinceReferenceDate, forKey: Keys.lastBackfillCursorTimeInterval)

            if inputs.isEmpty {
                statusNote = "Health backfill found no new step, distance, route, or heart-rate samples between \(startDate.formatted(date: .abbreviated, time: .shortened)) and \(endDate.formatted(date: .abbreviated, time: .shortened))."
            } else {
                statusNote = "Recovered \(inputs.count) Health samples on the iPhone (\(stepInputs.count) steps, \(distanceInputs.count) distance, \(routeInputs.count) route, \(heartRateInputs.count) heart rate) between \(startDate.formatted(date: .abbreviated, time: .shortened)) and \(endDate.formatted(date: .abbreviated, time: .shortened))."
            }
        } catch {
            statusNote = "Failed to persist Health backfill samples."
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
                    continuation.resume(returning: [])
                    return
                }

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
                    continuation.resume(returning: [])
                    return
                }

                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func workoutRouteInputs(for workouts: [HKWorkout]) async -> [ObservationInput] {
        var inputs = [ObservationInput]()

        for workout in workouts {
            let routes = await workoutRoutes(for: workout)
            for route in routes {
                let locations = await routeLocations(for: route)
                inputs.append(contentsOf: locations.compactMap { location in
                    makeRouteObservationInput(for: location, route: route, workout: workout)
                })
            }
        }

        return inputs
    }

    private func workoutRouteSeriesCount(for workouts: [HKWorkout]) async -> Int {
        var count = 0
        for workout in workouts {
            count += await workoutRoutes(for: workout).count
        }
        return count
    }

    private func workoutHeartRateInputs(for workouts: [HKWorkout]) async -> [ObservationInput] {
        var inputs = [ObservationInput]()

        for workout in workouts {
            let predicate = HKQuery.predicateForObjects(from: workout)
            let samples = await quantitySamples(
                identifier: .heartRate,
                startDate: workout.startDate,
                endDate: workout.endDate,
                additionalPredicate: predicate
            )

            inputs.append(contentsOf: samples.compactMap { sample in
                makeHeartRateObservationInput(for: sample, workout: workout)
            })
        }

        return inputs
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
                    continuation.resume(returning: [])
                    return
                }

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
                }

                if error != nil || done {
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
