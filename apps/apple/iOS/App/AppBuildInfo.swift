import Foundation

struct AppBuildInfo: Codable {
    let bundleIdentifier: String
    let shortVersion: String
    let buildNumber: String

    static var current: AppBuildInfo {
        let bundle = Bundle.main
        return AppBuildInfo(
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        )
    }
}
