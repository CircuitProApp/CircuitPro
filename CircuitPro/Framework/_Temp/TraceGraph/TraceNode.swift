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
            graph.traceData[edgeID]?.layerId
        }
        set {
            guard let newLayerID = newValue else {
                print("Warning: Attempted to assign a nil layer to a trace. Operation aborted.")
                return
            }
            if var data = graph.traceData[edgeID] {
                data.layerId = newLayerID
                graph.traceData[edgeID] = data
            }
        }
    }

    init(edgeID: GraphEdge.ID, graph: TraceGraph) {
        self.edgeID = edgeID
        self.graph = graph
        super.init(id: edgeID)
    }

    // --- THIS IS THE CORRECTED DRAWING LOGIC ---
    // We update the method signature to accept the RenderContext, which is standard practice
    // for nodes that need canvas-wide information to draw themselves.
    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
         guard let edge = graph.engine.currentState.edges[edgeID],
               let startVertex = graph.engine.currentState.vertices[edge.start],
               let endVertex = graph.engine.currentState.vertices[edge.end],
               let data = graph.traceData[edgeID] else {
             return []
         }

         let path = CGMutablePath()
         path.move(to: startVertex.point)
         path.addLine(to: endVertex.point)

         // --- THE FIX ---
         // Use the 'color' property which was set by the parent TraceGraphNode.
         return [.stroke(
             path: path,
             color: self.color, // Use the resolved color
             lineWidth: data.width,
             lineCap: .round
         )]
     }
     
    override func makeHaloPath() -> CGPath? {
        guard let edge = graph.engine.currentState.edges[edgeID],
              let startVertex = graph.engine.currentState.vertices[edge.start],
              let endVertex = graph.engine.currentState.vertices[edge.end],
              let data = graph.traceData[edgeID] else {
            return nil
        }

        let path = CGMutablePath()
        path.move(to: startVertex.point)
        path.addLine(to: endVertex.point)
        
        return path.copy(strokingWithWidth: data.width + 4.0, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }
}
