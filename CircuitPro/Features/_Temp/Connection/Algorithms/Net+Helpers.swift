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
}
