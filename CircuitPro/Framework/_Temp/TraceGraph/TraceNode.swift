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

    override var isSelectable: Bool { true }
    
    // --- THIS IS THE CORRECTED IMPLEMENTATION ---
    var layerId: UUID? {
        get {
            // The getter remains the same, reading from the central data store.
            graph.traceData[edgeID]?.layerId
        }
        set {
            // 1. Safely unwrap the incoming optional value. If it's nil,
            //    we cannot proceed because the data model requires a valid layer.
            guard let newLayerID = newValue else {
                print("Warning: Attempted to assign a nil layer to a trace. Operation aborted.")
                return
            }
            
            // 2. Check if the trace data entry exists.
            if var data = graph.traceData[edgeID] {
                // 3. Modify the tuple with the unwrapped, non-optional UUID.
                data.layerId = newLayerID
                // 4. Write the entire modified tuple back into the dictionary.
                graph.traceData[edgeID] = data
            }
        }
    }

    init(edgeID: GraphEdge.ID, graph: TraceGraph) {
        self.edgeID = edgeID
        self.graph = graph
        super.init(id: edgeID)
    }

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

        return [.stroke(
            path: path,
            color: .black, // This color will be replaced by the renderer's layer lookup.
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
