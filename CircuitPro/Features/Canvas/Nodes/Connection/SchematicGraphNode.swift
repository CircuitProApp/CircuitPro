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
    
    override func makeHaloPath() -> CGPath? {
        // This method will be called by the renderer. The renderer's context provides
        // the full set of highlighted node IDs.
        
        // We find which of our children are currently highlighted.
        let highlightedChildren = self.children.filter { child in
            // Assume you will have access to the context's highlighted IDs.
            // For now, let's conceptualize this. The renderer will manage this state.
            // Let's pretend we have a way to check: child.isHighlighted
            // The actual implementation will be in the renderer logic later.
            // Let's build the path logic for now.
            return true // For demonstration. The real check happens in the renderer.
        }
        
        // This logic will be moved to the renderer or a similar context-aware place.
        // For now, let's just make a composite path of ALL children for demonstration.
        
        let compositePath = CGMutablePath()

        // Iterate over ALL children to build a composite halo.
        // In the real implementation, you'd filter this list by selected children.
        for child in self.children {
            guard let wireNode = child as? WireNode,
                  let childHalo = wireNode.makeHaloPath() else {
                continue
            }
            
            // The child's halo is in its own coordinate space (world for a wire).
            // Since the wire node's transform is identity, no extra transform is needed here.
            compositePath.addPath(childHalo)
        }
        
        return compositePath.isEmpty ? nil : compositePath
    }
}
