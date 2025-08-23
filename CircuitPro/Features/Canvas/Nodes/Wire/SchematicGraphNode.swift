//
//  SchematicGraphNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit
import Observation
/// A special container node that manages the scene graph representation of a `WireGraph`.
///
/// This node doesn't draw anything itself. Its purpose is to hold a reference to the
/// `WireGraph` model and create, manage, and destroy `VertexNode` and `WireNode`
/// children to reflect the current state of the graph's topology. It serves as the root
/// for all schematic wiring visuals on the canvas.
@Observable
final class SchematicGraphNode: BaseNode {

    /// The single source of truth for the schematic's connectivity and geometry data.
    let graph: WireGraph

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
    init(graph: WireGraph) {
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
    
    override func nodes(intersecting rect: CGRect) -> [BaseNode] {
        var foundNodes: [BaseNode] = []
        
        // Since the SchematicGraphNode itself isn't selectable, we bypass
        // checking it and go straight to its children.
        for child in children where child.isVisible {
            // We call the base implementation on each child, allowing them to be found.
            foundNodes.append(contentsOf: child.nodes(intersecting: rect))
        }
        
        return foundNodes
    }
    
    override func makeHaloPath(context: RenderContext) -> CGPath? {
        // 1. Create a set of our child node IDs for efficient lookup.
        let childNodeIDs = Set(self.children.map { $0.id })

        // 2. Find which of our children are in the highlighted set from the context.
        let highlightedChildIDs = context.highlightedNodeIDs.intersection(childNodeIDs)
        
        guard !highlightedChildIDs.isEmpty else { return nil }

        // 3. Create a single path containing the center-lines of all selected wires.
        let compositePath = CGMutablePath()

        for childID in highlightedChildIDs {
            // We only care about WireNodes for this operation.
            guard let wireNode = self.children.first(where: { $0.id == childID }) as? WireNode,
                  let edge = graph.edges[wireNode.edgeID],
                  let startVertex = graph.vertices[edge.start],
                  let endVertex = graph.vertices[edge.end] else {
                continue
            }
            
            // Add the basic line segment to our composite path.
            compositePath.move(to: startVertex.point)
            compositePath.addLine(to: endVertex.point)
        }

        // 4. If we built a path, stroke the *entire composite path* at once.
        // This is the crucial step that creates a single, clean, unified halo.
        if !compositePath.isEmpty {
            return compositePath.copy(strokingWithWidth: 5.0, lineCap: .round, lineJoin: .round, miterLimit: 0)
        }
        
        return nil
    }
}

extension SchematicGraphNode {
    /// Generates a single, unified halo path for all of its children that are currently selected.
    /// This creates a clean, continuous highlight for a selected wire run.
    func makeHaloPathForSelectedWires(context: RenderContext) -> CGPath? {
        // 1. Find which of our children are `WireNode`s and are also in the set of highlighted nodes.
        let selectedWires = self.children.compactMap { child -> WireNode? in
            guard context.highlightedNodeIDs.contains(child.id) else { return nil }
            return child as? WireNode
        }
        
        guard !selectedWires.isEmpty else { return nil }

        // 2. Create a single path containing the center-lines of all selected wire segments.
        let compositePath = CGMutablePath()

        for wireNode in selectedWires {
            // It is safe to unwrap here because a WireNode must have a valid edge to exist.
            let edge = graph.edges[wireNode.edgeID]!
            let startVertex = graph.vertices[edge.start]!
            let endVertex = graph.vertices[edge.end]!
            
            compositePath.move(to: startVertex.point)
            compositePath.addLine(to: endVertex.point)
        }

        // 3. Stroke the entire composite path at once. The result is a new path
        // that outlines the stroke, which should be filled.
        return compositePath.copy(strokingWithWidth: 5.0, lineCap: .round, lineJoin: .round, miterLimit: 0)
    }
}
