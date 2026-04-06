import Foundation

struct WatchIntakeMetadataSnapshot: Codable {
    let captureSessionID: UUID
    let batchSequence: Int
    let sentAt: Date
    let senderAppVersion: String
    let senderBuildNumber: String
    let observationCount: Int
    let transport: String

    static let userDefaultsKey = "watch.latestIntakeMetadata"

    static func load() -> WatchIntakeMetadataSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }

        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}
