import Foundation

struct RemoveIsolatedFreeVerticesRule: NormalizationRule {
    func apply(to state: inout NormalizationState) {
        var adjacencyCount: [UUID: Int] = [:]
        adjacencyCount.reserveCapacity(state.pointsByID.count)

        for link in state.links {
            adjacencyCount[link.startID, default: 0] += 1
            adjacencyCount[link.endID, default: 0] += 1
        }

        for (id, pointObj) in state.pointsByObject {
            guard pointObj is WireVertex else { continue }
            guard adjacencyCount[id] == nil else { continue }
            state.pointsByID.removeValue(forKey: id)
            state.removedPointIDs.insert(id)
        }
    }
}
