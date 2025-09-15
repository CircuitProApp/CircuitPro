//
//  TraceNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import AppKit
import Observation

@Observable
final class TraceNode: BaseNode, Layerable {
    let edgeID: GraphEdge.ID
    let graph: TraceGraph
    
    var color: CGColor = NSColor.black.cgColor

    override var isSelectable: Bool { true }
    
    var layerId: UUID? {
        get {
            // --- MODIFIED: Access the new edgeMetadata dictionary and struct property ---
            graph.edgeMetadata[edgeID]?.layerId
        }
        set {
            guard let newLayerID = newValue else {
                print("Warning: Attempted to assign a nil layer to a trace. Operation aborted.")
                return
            }
            // --- MODIFIED: Update the struct within the new dictionary ---
            if var metadata = graph.edgeMetadata[edgeID] {
                metadata = TraceEdgeMetadata(width: metadata.width, layerId: newLayerID)
                graph.edgeMetadata[edgeID] = metadata
            }
        }
    }

    init(edgeID: GraphEdge.ID, graph: TraceGraph) {
        self.edgeID = edgeID
        self.graph = graph
        super.init(id: edgeID)
    }
    
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // First, give any potential children a chance to be hit. This is good practice,
        // even though TraceNode currently has no children.
        if let childHit = super.hitTest(point, tolerance: tolerance) {
            return childHit
        }

        // Now, check if the point hits this node's own geometry.
        // We use the halo path to create a generous, easy-to-click area.
        guard let haloPath = self.makeHaloPath() else {
            return nil
        }
        
        // The core of the fix: check if the point is inside the path.
        if haloPath.contains(point) {
            // It's a hit! Return a CanvasHitTarget describing this node.
            return CanvasHitTarget(
                node: self,
                partIdentifier: nil, // We don't need to identify sub-parts of a trace.
                position: point
            )
        }

        // If the point is not within our halo, it's a miss.
        return nil
    }

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        guard let edge = graph.engine.currentState.edges[edgeID],
              let startVertex = graph.engine.currentState.vertices[edge.start],
              let endVertex = graph.engine.currentState.vertices[edge.end] else {
            return []
        }

        let metadata = graph.edgeMetadata[edgeID]
        let width = metadata?.width ?? 1.0 // fallback so it still draws

        let path = CGMutablePath()
        path.move(to: startVertex.point)
        path.addLine(to: endVertex.point)

        return [.stroke(
            path: path,
            color: self.color,
            lineWidth: width,
            lineCap: .round
        )]
    }
     
    override func makeHaloPath() -> CGPath? {
        guard let edge = graph.engine.currentState.edges[edgeID],
              let startVertex = graph.engine.currentState.vertices[edge.start],
              let endVertex = graph.engine.currentState.vertices[edge.end] else {
            return nil
        }

        let width = (graph.edgeMetadata[edgeID]?.width ?? 1.0) + 4.0

        let path = CGMutablePath()
        path.move(to: startVertex.point)
        path.addLine(to: endVertex.point)
        return path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }
}
