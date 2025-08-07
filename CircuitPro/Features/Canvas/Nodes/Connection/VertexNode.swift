//
//  VertexNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit

/// A scene graph node representing a single vertex from the `SchematicGraph`.
/// This node contains the logic to decide if and how it should be rendered,
/// typically as a dot at a junction of three or more wires.
final class VertexNode: BaseNode {

    let vertexID: ConnectionVertex.ID
    let graph: SchematicGraph
    
    /// A debug flag to force rendering of all vertices, not just junctions.
    var isInDebugMode: Bool = false

    override var isSelectable: Bool { false }

    /// The node's position is always sourced directly from the graph model to ensure it's live.
    override var position: CGPoint {
        get { graph.vertices[vertexID]?.point ?? .zero }
        set { /* The graph's drag logic manipulates the vertex position directly. */ }
    }

    init(vertexID: ConnectionVertex.ID, graph: SchematicGraph) {
        self.vertexID = vertexID
        self.graph = graph
        super.init(id: vertexID)
    }
    
    /// Creates the drawing parameters for the vertex.
    override func makeBodyParameters() -> [DrawingParameters] {
        // A vertex should be visually rendered only if it's a junction (or if debugging).
        // A junction is defined as a vertex connecting 3 or more wires.
        let connectionCount = graph.adjacency[vertexID]?.count ?? 0
        let isJunction = connectionCount > 2

        guard isJunction || isInDebugMode else {
            return [] // Render nothing for simple corners (2 connections) or endpoints (1 connection).
        }

        // All visible vertices are drawn the same way (a small circle).
        let path = CGPath(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4), transform: nil)
        
        // Use a different color to highlight that debug mode is active.
        let color = isInDebugMode ? NSColor.systemOrange.cgColor : NSColor.controlAccentColor.cgColor

        return [
            DrawingParameters(path: path, lineWidth: 1.0,
                              fillColor: color)
        ]
    }
}
