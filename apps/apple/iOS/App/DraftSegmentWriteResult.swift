import Foundation

struct DraftSegmentWriteResult {
    let segment: SegmentRecord
    let action: DraftSegmentWriteAction
}

enum DraftSegmentWriteAction {
    case created
    case updated
}
