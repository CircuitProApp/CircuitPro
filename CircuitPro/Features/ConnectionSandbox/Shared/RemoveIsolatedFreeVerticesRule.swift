import CoreGraphics
import Foundation

struct RemoveIsolatedFreeVerticesRule<FreePoint, Link: ConnectionLink> {
    func apply(
        pointsByID: inout [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        links: [Link],
        removedPointIDs: inout Set<UUID>
    ) {
        var adjacencyCount: [UUID: Int] = [:]
        adjacencyCount.reserveCapacity(pointsByID.count)

        for link in links {
            adjacencyCount[link.startID, default: 0] += 1
            adjacencyCount[link.endID, default: 0] += 1
        }

        for (id, pointObj) in pointsByObject {
            guard pointObj is FreePoint else { continue }
            guard adjacencyCount[id] == nil else { continue }
            pointsByID.removeValue(forKey: id)
            removedPointIDs.insert(id)
        }
    }
}
