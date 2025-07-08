import Foundation

final class NetRepository {
    private(set) var nets: [Net] = []
    var mergePolicy: MergePolicy

    init(mergePolicy: MergePolicy = DefaultMergePolicy()) {
        self.mergePolicy = mergePolicy
    }

    func add(_ net: Net) {
        nets.append(net)
    }

    func allNets() -> [Net] {
        nets
    }
}
