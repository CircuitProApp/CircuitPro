//
//  SchematicGraphNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit
import Observation
/// A special container node that manages the scene graph representation of a `SchematicGraph`.
///
/// This node doesn't draw anything itself. Its purpose is to hold a reference to the
/// `SchematicGraph` model and create, manage, and destroy `VertexNode` and `WireNode`
/// children to reflect the current state of the graph's topology. It serves as the root
/// for all schematic wiring visuals on the canvas.
@Observable
final class SchematicGraphNode: BaseNode {

    /// The single source of truth for the schematic's connectivity and geometry data.
    let graph: SchematicGraph

    /// A flag to enable debug visualizations for vertices. When set, it's passed
    /// down to all child `VertexNode` instances.
    var showAllVertices: Bool = false {
        didSet {
            // If the flag changes, update all existing child vertex nodes and request a redraw.
            guard oldValue != showAllVertices else { return }
            for child in children {
                if let vertexNode = child as? VertexNode {
                    vertexNode.isInDebugMode = showAllVertices
                }
            }
            onNeedsRedraw?()
        }
    }

    /// This node is a container and should not be directly selectable.
    /// Its children (`WireNode`s) are the selectable entities.
    override var isSelectable: Bool { false }

    /// Initializes the node with the graph data model.
    /// - Parameter graph: The `SchematicGraph` instance that this node will visually represent.
    init(graph: SchematicGraph) {
        self.graph = graph
        // The container needs its own unique, stable ID.
        super.init(id: UUID())
    }

    /// This is the core synchronization method. It rebuilds the node hierarchy to match the model.
    ///
    /// Call this method whenever the graph's topology changes (e.g., after a 'delete'
    /// operation, or at the end of a drag-and-normalize sequence), but *not* during
    /// continuous operations like a drag update.
    func syncChildNodesFromModel() {
        // A simple and robust way to sync is to remove all children and recreate them
        // from the latest state of the graph model.
        self.children.removeAll()

        // 1. Create a VertexNode for every vertex in the graph.
        for vertex in graph.vertices.values {
            let vertexNode = VertexNode(vertexID: vertex.id, graph: graph)
            vertexNode.isInDebugMode = self.showAllVertices // Pass down debug state
            self.addChild(vertexNode)
        }
        
        // 2. Create a WireNode for every edge in the graph.
        for edge in graph.edges.values {
            // Note: We pass the edge's ID, not the edge struct itself.
            let wireNode = WireNode(edgeID: edge.id, graph: graph)
            self.addChild(wireNode)
        }
        
        // 3. Crucially, signal to the canvas that this part of the scene has changed
        // and needs to be redrawn in the next render pass.
        self.onNeedsRedraw?()
    }
}
