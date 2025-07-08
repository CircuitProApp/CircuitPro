import Foundation

enum MergeStage {
    case perEdge
    case perRoute
    case afterCommit
}

protocol MergePolicy {
    func shouldMerge(_ newNet: Net, into existing: Net, at stage: MergeStage) -> Bool
}

struct DefaultMergePolicy: MergePolicy {
    func shouldMerge(_ newNet: Net, into existing: Net, at stage: MergeStage) -> Bool {
        true
    }
}

