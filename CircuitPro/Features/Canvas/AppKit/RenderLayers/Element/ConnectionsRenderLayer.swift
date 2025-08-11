import AppKit

class ConnectionsRenderLayer: RenderLayer {
    var layerKey: String = "connections"

    // 1. The layers are already persistent properties. This is correct.
    private let highlightLayer = CAShapeLayer()
    private let edgesLayer = CAShapeLayer()
    private let junctionsLayer = CAShapeLayer()
    private let verticesLayer = CAShapeLayer()

    init() {
        // The init method correctly sets up the constant layer styles. This is perfect.
        highlightLayer.lineWidth = 5.0
        highlightLayer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        highlightLayer.fillColor = nil
        highlightLayer.lineCap = .round
        
        edgesLayer.lineWidth = 1.5
        edgesLayer.strokeColor = NSColor.systemBlue.cgColor
        edgesLayer.fillColor = nil
        
        junctionsLayer.fillColor = NSColor.systemBlue.cgColor
        verticesLayer.fillColor = NSColor.systemPurple.cgColor
    }

    /// **NEW:** Called once to add the persistent layers to the host layer tree in the correct Z-order.
    func install(on hostLayer: CALayer) {
        // The order of insertion determines the drawing order (bottom to top).
        hostLayer.addSublayer(highlightLayer)
        hostLayer.addSublayer(edgesLayer)
        hostLayer.addSublayer(junctionsLayer)
        hostLayer.addSublayer(verticesLayer)
    }

    /// **NEW:** Updates the paths of the existing layers on every redraw.
    func update(using context: RenderContext) {
        let allSelected = context.selectedIDs.union(context.marqueeSelectedIDs)
        let graph = context.schematicGraph
        
        let vertexRadius: CGFloat = 2.0
        let junctionRadius: CGFloat = 4.0

        // Highlight Path
        let highlightPath = CGMutablePath()
        for selectedID in allSelected {
            if let edge = graph.edges[selectedID],
               let startVertex = graph.vertices[edge.start],
               let endVertex = graph.vertices[edge.end] {
                highlightPath.move(to: startVertex.point)
                highlightPath.addLine(to: endVertex.point)
            }
        }
        highlightLayer.path = highlightPath
        
        // Edges Path
        let edgesPath = CGMutablePath()
        for edge in graph.edges.values {
            if let startVertex = graph.vertices[edge.start],
               let endVertex = graph.vertices[edge.end] {
                edgesPath.move(to: startVertex.point)
                edgesPath.addLine(to: endVertex.point)
            }
        }
        edgesLayer.path = edgesPath
        
        // Junctions and Vertices Paths
        let junctionsPath = CGMutablePath()
        let verticesPath = CGMutablePath()
        for vertex in graph.vertices.values {
            let vertexRect = CGRect(x: vertex.point.x - vertexRadius, y: vertex.point.y - vertexRadius, width: vertexRadius * 2, height: vertexRadius * 2)
            verticesPath.addEllipse(in: vertexRect)
            
            let connectionCount = graph.adjacency[vertex.id]?.count ?? 0
            var isJunction = false
            if case .pin = vertex.ownership {
                if connectionCount >= 2 { isJunction = true }
            } else {
                if connectionCount > 2 { isJunction = true }
            }
            
            if isJunction {
                let junctionRect = CGRect(x: vertex.point.x - junctionRadius, y: vertex.point.y - junctionRadius, width: junctionRadius * 2, height: junctionRadius * 2)
                junctionsPath.addEllipse(in: junctionRect)
            }
        }
        junctionsLayer.path = junctionsPath
        verticesLayer.path = verticesPath
    }
    
    /// The hit-testing logic remains unchanged.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        let tolerance = 5.0 / context.magnification
        return WorkbenchHitTestService.hitTestSchematicGraph(at: point, graph: context.schematicGraph, tolerance: tolerance)
    }
}
