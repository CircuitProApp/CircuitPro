import AppKit
import Observation
@Observable
final class VertexNode: BaseNode {
    let vertexID: ConnectionVertex.ID
    let graph: SchematicGraph
    var isInDebugMode: Bool = true

    // A vertex is not selectable by the main cursor, but it must be hittable by tools.
    override var isSelectable: Bool { false }

    override var position: CGPoint {
        get { graph.vertices[vertexID]?.point ?? .zero }
        set { /* Model is mutated by graph logic directly */ }
    }

    // --- NEW: Add a computed property for the vertex type ---
    var type: VertexType {
        guard let adjacency = graph.adjacency[vertexID] else { return .endpoint } // Default for safety
        switch adjacency.count {
        case 0, 1: return .endpoint
        case 2: return .corner
        default: return .junction
        }
    }

    init(vertexID: ConnectionVertex.ID, graph: SchematicGraph) {
        self.vertexID = vertexID
        self.graph = graph
        super.init(id: vertexID)
    }

    // --- NEW: Implement hitTest to return enriched information ---
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        let size = 4.0 + tolerance // A small touch target around the vertex
        let bounds = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        
        guard bounds.contains(point) else { return nil }

        // When hit, package its specific type into the partIdentifier.
        return CanvasHitTarget(node: self, partIdentifier: self.type, position: self.position)
    }
    
    override func makeBodyParameters() -> [DrawingParameters] {
        // We can now use the computed property here as well.
        guard self.type == .junction || isInDebugMode else { return [] }
        
        let path = CGPath(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4), transform: nil)
        let color = isInDebugMode ? NSColor.systemOrange.cgColor : NSColor.controlAccentColor.cgColor

        return [DrawingParameters(path: path, fillColor: color)]
    }
}
