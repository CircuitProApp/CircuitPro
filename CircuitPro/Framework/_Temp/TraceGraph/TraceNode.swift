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

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
         guard let edge = graph.engine.currentState.edges[edgeID],
               let startVertex = graph.engine.currentState.vertices[edge.start],
               let endVertex = graph.engine.currentState.vertices[edge.end],
               // --- MODIFIED: Read from the new edgeMetadata dictionary ---
               let metadata = graph.edgeMetadata[edgeID] else {
             return []
         }

         let path = CGMutablePath()
         path.move(to: startVertex.point)
         path.addLine(to: endVertex.point)

         return [.stroke(
             path: path,
             color: self.color, // Use the resolved color
             // --- MODIFIED: Access the .width property from the metadata struct ---
             lineWidth: metadata.width,
             lineCap: .round
         )]
     }
     
    override func makeHaloPath() -> CGPath? {
        guard let edge = graph.engine.currentState.edges[edgeID],
              let startVertex = graph.engine.currentState.vertices[edge.start],
              let endVertex = graph.engine.currentState.vertices[edge.end],
              // --- MODIFIED: Read from the new edgeMetadata dictionary ---
              let metadata = graph.edgeMetadata[edgeID] else {
            return nil
        }

        let path = CGMutablePath()
        path.move(to: startVertex.point)
        path.addLine(to: endVertex.point)
        
        // --- MODIFIED: Access the .width property from the metadata struct ---
        return path.copy(strokingWithWidth: metadata.width + 4.0, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }
}
