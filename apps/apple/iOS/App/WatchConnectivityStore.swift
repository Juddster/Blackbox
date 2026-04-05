import Foundation
import Observation
import SwiftData
import WatchConnectivity

@MainActor
@Observable
final class WatchConnectivityStore {
    var isSupported = WCSession.isSupported()
    var isPaired = false
    var isWatchAppInstalled = false
    var isReachable = false
    var activationState: WCSessionActivationState = .notActivated
    var statusNote: String?
    var lastReceivedAt: Date?
    var receivedBatchCount = 0
    var decodedBatchCount = 0
    var persistedBatchCount = 0
    var decodeFailureCount = 0
    var persistFailureCount = 0
    var totalReceivedObservationCount = 0
    var lastReceivedObservationCount = 0
    var lastReceivedLocationCount = 0
    var lastReceivedMotionCount = 0
    var lastReceivedPedometerCount = 0
    var lastReceiveTransport = "None"

    private var recorder: LocalObservationRecorder?
    private var session: WCSession?
    private var delegateProxy: WatchConnectivityDelegateProxy?

    var connectionSummary: String {
        guard isSupported else {
            return "Unavailable"
        }

        switch activationState {
        case .activated:
            return isReachable ? "Reachable" : "Background Ready"
        case .inactive:
            return "Inactive"
        case .notActivated:
            return "Not Activated"
        @unknown default:
            return "Unknown"
        }
    }

    var installationSummary: String {
        guard isSupported else {
            return "No Apple Watch"
        }

        if isPaired == false {
            return "Not Paired"
        }

        return isWatchAppInstalled ? "Installed" : "Missing"
    }

    var lastReceivedSummary: String? {
        guard let lastReceivedAt else {
            return nil
        }

        return "\(lastReceivedAt.formatted(date: .omitted, time: .shortened)) • \(lastReceivedObservationCount) observations"
    }

    var lastReceivedBreakdownSummary: String? {
        guard lastReceivedObservationCount > 0 else {
            return nil
        }

        return "\(lastReceivedLocationCount) location • \(lastReceivedMotionCount) motion • \(lastReceivedPedometerCount) pedometer"
    }

    var diagnosticsSummary: String {
        "received \(receivedBatchCount) • decoded \(decodedBatchCount) • persisted \(persistedBatchCount) • decode failures \(decodeFailureCount) • persist failures \(persistFailureCount)"
    }

    func configure(modelContext: ModelContext) {
        recorder = LocalObservationRecorder(modelContext: modelContext)

        guard WCSession.isSupported() else {
            isSupported = false
            statusNote = "This iPhone does not support Apple Watch communication."
            return
        }

        if session == nil {
            let proxy = WatchConnectivityDelegateProxy()
            proxy.onActivationChange = { [weak self] activationState, error in
                Task { @MainActor in
                    self?.activationState = activationState
                    self?.refreshState()
                    if let error {
                        self?.statusNote = "Watch session activation failed: \(error.localizedDescription)"
                    }
                }
            }
            proxy.onWatchStateChange = { [weak self] in
                Task { @MainActor in
                    self?.refreshState()
                }
            }
            proxy.onUserInfo = { [weak self] userInfo in
                Task { @MainActor in
                    await self?.ingestPayload(from: userInfo, transport: "userInfo")
                }
            }
            proxy.onApplicationContext = { [weak self] context in
                Task { @MainActor in
                    await self?.ingestPayload(from: context, transport: "applicationContext")
                }
            }
            proxy.onFile = { [weak self] fileURL in
                Task { @MainActor in
                    await self?.ingestPayload(fromFileAt: fileURL, transport: "file")
                }
            }

            let session = WCSession.default
            session.delegate = proxy
            session.activate()

            self.session = session
            self.delegateProxy = proxy
        }

        refreshState()
    }

    private func refreshState() {
        guard let session else {
            return
        }

        isSupported = WCSession.isSupported()
        activationState = session.activationState
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable

        if isPaired == false {
            statusNote = "Pair an Apple Watch to add watch motion, pedometer, and location as sources."
        } else if isWatchAppInstalled == false {
            statusNote = "The Apple Watch is paired, but the Blackbox watch app is not installed yet."
        } else if lastReceivedAt == nil {
            statusNote = "Watch intake is ready for best-effort passive enrichment batches from the Apple Watch."
        } else {
            statusNote = "Receiving watch observations over Watch Connectivity for replay export and inference review."
        }
    }

    private func ingestPayload(from dictionary: [String: Any], transport: String) async {
        guard let payloadData = dictionary[WatchObservationTransferEnvelope.payloadKey] as? Data else {
            return
        }

        receivedBatchCount += 1
        lastReceiveTransport = transport
        await ingestPayloadData(payloadData)
    }

    private func ingestPayload(fromFileAt fileURL: URL, transport: String) async {
        guard let payloadData = try? Data(contentsOf: fileURL) else {
            return
        }

        receivedBatchCount += 1
        lastReceiveTransport = transport
        await ingestPayloadData(payloadData)
    }

    private func ingestPayloadData(_ payloadData: Data) async {
        guard let recorder else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let envelope = try? decoder.decode(WatchObservationTransferEnvelope.self, from: payloadData) else {
            decodeFailureCount += 1
            statusNote = "Received a watch payload, but Blackbox could not decode it."
            return
        }
        decodedBatchCount += 1

        let inputs = envelope.observations.map { observation in
            ObservationInput(
                id: observation.id,
                timestamp: observation.timestamp,
                sourceDevice: .watch,
                sourceType: observation.sourceType,
                payload: observation.payload,
                qualityHint: observation.qualityHint,
                ingestedAt: observation.ingestedAt ?? envelope.sentAt
            )
        }

        guard inputs.isEmpty == false else {
            return
        }

        do {
            try recorder.record(inputs)
            persistedBatchCount += 1
            totalReceivedObservationCount += inputs.count
            lastReceivedLocationCount = inputs.filter { $0.sourceType == .location }.count
            lastReceivedMotionCount = inputs.filter { $0.sourceType == .motion }.count
            lastReceivedPedometerCount = inputs.filter { $0.sourceType == .pedometer }.count
            lastReceivedAt = .now
            lastReceivedObservationCount = inputs.count
            statusNote = "Received \(inputs.count) watch observations via \(lastReceiveTransport)."
        } catch {
            persistFailureCount += 1
            statusNote = "Failed to persist watch observations."
        }
    }
}

private final class WatchConnectivityDelegateProxy: NSObject, WCSessionDelegate {
    var onActivationChange: ((WCSessionActivationState, Error?) -> Void)?
    var onWatchStateChange: (() -> Void)?
    var onUserInfo: (([String: Any]) -> Void)?
    var onApplicationContext: (([String: Any]) -> Void)?
    var onFile: ((URL) -> Void)?

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        onActivationChange?(activationState, error)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        onWatchStateChange?()
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        onWatchStateChange?()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        onWatchStateChange?()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        onUserInfo?(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        onApplicationContext?(applicationContext)
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        onFile?(file.fileURL)
    }
}
