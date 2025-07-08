import Foundation
import CoreGraphics

extension Net {
    func nodeID(at point: CGPoint, tolerance: CGFloat = 0.5) -> UUID? {
        nodeByID.first { _, node in
            abs(node.point.x - point.x) < tolerance &&
            abs(node.point.y - point.y) < tolerance
        }?.key
    }

    func edgeID(containing point: CGPoint, tolerance: CGFloat = 0.5) -> UUID? {
        for edge in edges {
            guard let start = nodeByID[edge.startNodeID]?.point,
                  let end = nodeByID[edge.endNodeID]?.point else { continue }
            let segment = LineSegment(start: start, end: end)
            if segment.contains(point, tolerance: tolerance) {
                return edge.id
            }
        }
        return nil
    }

    mutating func replaceNodeID(_ oldID: UUID, with newID: UUID) {
        if oldID == newID { return }
        for i in edges.indices {
            if edges[i].startNodeID == oldID { edges[i].startNodeID = newID }
            if edges[i].endNodeID == oldID { edges[i].endNodeID = newID }
        }
        if let node = nodeByID.removeValue(forKey: oldID) {
            nodeByID[newID] = nodeByID[newID] ?? Node(id: newID, point: node.point, kind: node.kind)
        }
    }

    mutating func downgradeRedundantJunctions() {
        var degree: [UUID: Int] = [:]
        for edge in edges {
            degree[edge.startNodeID, default: 0] += 1
            degree[edge.endNodeID, default: 0] += 1
        }
        for (id, node) in nodeByID where node.kind == .junction {
            if degree[id, default: 0] <= 2 {
                var updated = node
                updated.kind = .endpoint
                nodeByID[id] = updated
            }
        }
    }
}
