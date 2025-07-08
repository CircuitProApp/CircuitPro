import Foundation

final class NetRepository {
    private(set) var nets: [Net] = []

    func add(_ net: Net) {
        nets.append(net)
    }

    func allNets() -> [Net] {
        nets
    }
}
