//import AppKit
//
//class ConnectionsRenderLayer: RenderLayer {
//    var layerKey: String = "connections"
//
//    private let highlightLayer = CAShapeLayer()
//    private let edgesLayer = CAShapeLayer()
//    private let junctionsLayer = CAShapeLayer()
//    private let verticesLayer = CAShapeLayer()
//
//    init() {
//        highlightLayer.lineWidth = 5.0
//        highlightLayer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
//        highlightLayer.fillColor = nil
//        highlightLayer.lineCap = .round
//        
//        edgesLayer.lineWidth = 1.5
//        edgesLayer.strokeColor = NSColor.systemBlue.cgColor
//        edgesLayer.fillColor = nil
//        
//        junctionsLayer.fillColor = NSColor.systemBlue.cgColor
//        verticesLayer.fillColor = NSColor.systemPurple.cgColor
//    }
//
//    func install(on hostLayer: CALayer) {
//        hostLayer.addSublayer(highlightLayer)
//        hostLayer.addSublayer(edgesLayer)
//        hostLayer.addSublayer(junctionsLayer)
//        hostLayer.addSublayer(verticesLayer)
//    }
//
//    func update(using context: RenderContext) {
//        // This layer now correctly uses the unified set of IDs to highlight.
//        let highlightedIDs = context.highlightedNodeIDs
//        let graph = context.schematicGraph
//        
//        let vertexRadius: CGFloat = 2.0
//        let junctionRadius: CGFloat = 4.0
//
//        // Highlight Path - build the path from the new `highlightedNodeIDs`.
//        let highlightPath = CGMutablePath()
//        for selectedID in highlightedIDs {
//            if let edge = graph.edges[selectedID],
//               let startVertex = graph.vertices[edge.start],
//               let endVertex = graph.vertices[edge.end] {
//                highlightPath.move(to: startVertex.point)
//                highlightPath.addLine(to: endVertex.point)
//            }
//        }
//        highlightLayer.path = highlightPath
//        
//        // --- The rest of the drawing logic is unchanged as it was already correct. ---
//
//        // Edges Path
//        let edgesPath = CGMutablePath()
//        for edge in graph.edges.values {
//            if let startVertex = graph.vertices[edge.start],
//               let endVertex = graph.vertices[edge.end] {
//                edgesPath.move(to: startVertex.point)
//                edgesPath.addLine(to: endVertex.point)
//            }
//        }
//        edgesLayer.path = edgesPath
//        
//        // Junctions and Vertices Paths
//        let junctionsPath = CGMutablePath()
//        let verticesPath = CGMutablePath()
//        for vertex in graph.vertices.values {
//            let vertexRect = CGRect(x: vertex.point.x - vertexRadius, y: vertex.point.y - vertexRadius, width: vertexRadius * 2, height: vertexRadius * 2)
//            verticesPath.addEllipse(in: vertexRect)
//            
//            let connectionCount = graph.adjacency[vertex.id]?.count ?? 0
//            var isJunction = false
//            if case .pin = vertex.ownership {
//                if connectionCount >= 2 { isJunction = true }
//            } else {
//                if connectionCount > 2 { isJunction = true }
//            }
//            
//            if isJunction {
//                let junctionRect = CGRect(x: vertex.point.x - junctionRadius, y: vertex.point.y - junctionRadius, width: junctionRadius * 2, height: junctionRadius * 2)
//                junctionsPath.addEllipse(in: junctionRect)
//            }
//        }
//        junctionsLayer.path = junctionsPath
//        verticesLayer.path = verticesPath
//    }
//    
//    // The hit-testing logic for this layer remains unchanged for now.
//    // It will be refactored later to integrate more cleanly.
//    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
//        let tolerance = 5.0 / max(context.magnification, .ulpOfOne)
//        // Note: This still uses the old hit-testing logic for schematics.
//        // We will refactor this later to be more consistent.
//        if let target = SchematicGraphHitTestService.hitTest(at: point, graph: context.schematicGraph, tolerance: tolerance) {
//            // We need to convert the old CanvasHitTarget to the new CanvasHitResult.
//            // For now, we find the node in the scene graph.
//            if let node = findNode(with: target.partID, in: context.sceneRoot) {
//                return nil /*CanvasHitResult(node: node, kind: target.kind, position: target.position)*/
//            }
//        }
//        return nil
//    }
//
//    // Temporary helper to bridge the old hit-test to the new model.
//    private func findNode(with id: UUID, in root: any CanvasNode) -> (any CanvasNode)? {
//        if root.id == id { return root }
//        for child in root.children {
//            if let found = findNode(with: id, in: child) { return found }
//        }
//        return nil
//    }
//}
