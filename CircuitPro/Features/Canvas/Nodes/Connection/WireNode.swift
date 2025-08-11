import AppKit
import Observation

@Observable
final class WireNode: BaseNode {
    let edgeID: WireEdge.ID
    let graph: WireGraph

    override var isSelectable: Bool { true }

    var orientation: LineOrientation {
        guard let edge = graph.edges[edgeID],
              let startV = graph.vertices[edge.start],
              let endV = graph.vertices[edge.end] else {
            return .horizontal
        }
        
        return abs(startV.point.x - endV.point.x) < 1e-6 ? .vertical : .horizontal
    }

    init(edgeID: WireEdge.ID, graph: WireGraph) {
        self.edgeID = edgeID
        self.graph = graph
        super.init(id: edgeID)
    }

    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        guard let edge = graph.edges[edgeID],
              let startV = graph.vertices[edge.start],
              let endV = graph.vertices[edge.end],
              isPoint(point, onSegmentBetween: startV.point, p2: endV.point, tolerance: tolerance) else {
            return nil
        }
        
        return CanvasHitTarget(node: self, partIdentifier: self.orientation, position: point)
    }
    
    // UPDATED: This method now returns DrawingPrimitive.
    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        // NOTE: This node draws directly in world coordinates, which is a special case.
        // Its own transform is identity.
        guard let edge = graph.edges[edgeID],
              let startVertex = graph.vertices[edge.start],
              let endVertex = graph.vertices[edge.end] else {
            return []
        }

        let path = CGMutablePath()
        path.move(to: startVertex.point)
        path.addLine(to: endVertex.point)

        // Return a specific .stroke command.
        return [.stroke(
            path: path,
            color: NSColor.controlAccentColor.cgColor,
            lineWidth: 1.0,
            lineCap: .round
        )]
    }
    
    override func makeHaloPath() -> CGPath? {
        guard let edge = graph.edges[edgeID],
              let startVertex = graph.vertices[edge.start],
              let endVertex = graph.vertices[edge.end] else {
            return nil
        }
        
        let path = CGMutablePath()
        path.move(to: startVertex.point)
        path.addLine(to: endVertex.point)
        
        return path.copy(strokingWithWidth: 4.0, lineCap: .round, lineJoin: .round, miterLimit: 0)
    }
    
    private func isPoint(_ p: CGPoint, onSegmentBetween p1: CGPoint, p2: CGPoint, tolerance: CGFloat) -> Bool {
        let minX = min(p1.x, p2.x) - tolerance, maxX = max(p1.x, p2.x) + tolerance
        let minY = min(p1.y, p2.y) - tolerance, maxY = max(p1.y, p2.y) + tolerance

        guard p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY else { return false }

        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        let epsilon: CGFloat = 1e-6
        if abs(dx) < epsilon { return abs(p.x - p1.x) < tolerance }
        if abs(dy) < epsilon { return abs(p.y - p1.y) < tolerance }

        let distance = abs(dy * p.x - dx * p.y + p2.y * p1.x - p2.x * p1.y) / hypot(dx, dy)
        
        return distance < tolerance
    }
}
