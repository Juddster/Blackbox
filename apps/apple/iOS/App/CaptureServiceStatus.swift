import Foundation

struct CaptureServiceStatus: Identifiable {
    let kind: CaptureServiceKind
    let isAvailable: Bool
    let authorizationState: CaptureAuthorizationState
    let note: String?

    var id: CaptureServiceKind { kind }
}
