import AppKit
import Observation

@Observable
final class VertexNode: BaseNode {
    let vertexID: GraphVertex.ID
    let graph: WireGraph
    var isInDebugMode: Bool = true

    // A vertex is not selectable by the main cursor, but it must be hittable by tools.
    override var isSelectable: Bool { false }

    override var position: CGPoint {
        get { graph.vertices[vertexID]?.point ?? .zero }
        set { /* Model is mutated by graph logic directly */ }
    }

    var type: VertexType {
        guard let adjacency = graph.adjacency[vertexID] else { return .endpoint }
        switch adjacency.count {
        case 0, 1: return .endpoint
        case 2: return .corner
        default: return .junction
        }
    }

    init(vertexID: GraphVertex.ID, graph: WireGraph) {
        self.vertexID = vertexID
        self.graph = graph
        super.init(id: vertexID)
    }

    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        let size = 4.0 + tolerance
        let bounds = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        
        guard bounds.contains(point) else { return nil }
        
        return CanvasHitTarget(node: self, partIdentifier: self.type, position: self.position)
    }
    
    // UPDATED: This method now returns DrawingPrimitive.
    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        guard self.type == .junction || isInDebugMode else { return [] }
        
        // The path is defined in local space, centered on the node's position.
        let path = CGPath(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4), transform: nil)
        let color = isInDebugMode ? NSColor.systemOrange.cgColor : NSColor.controlAccentColor.cgColor

        // Return a specific .fill command.
        return [.fill(path: path, color: color)]
    }
}
