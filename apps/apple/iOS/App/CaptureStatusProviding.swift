import Foundation

protocol CaptureStatusProviding {
    var kind: CaptureServiceKind { get }
    func currentStatus() -> CaptureServiceStatus
}
