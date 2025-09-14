//
//  TraceGraphNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//


//
//  TraceGraphNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import AppKit
import Observation

/// A special container node that manages the scene graph representation of a `TraceGraph`.
///
/// This node doesn't draw anything itself. Its purpose is to hold a reference to the
/// `TraceGraph` model and create `TraceNode` children to reflect the current
/// state of the graph's edges. It serves as the root for all layout trace visuals on the canvas.
@Observable
final class TraceGraphNode: BaseNode {

    /// The single source of truth for the layout's trace connectivity and geometry data.
    let graph: TraceGraph

    /// This node is a container and should not be directly selectable.
    /// Its children (`TraceNode`s) are the selectable entities.
    override var isSelectable: Bool { false }

    /// Initializes the node with the graph data model.
    /// - Parameter graph: The `TraceGraph` instance that this node will visually represent.
    init(graph: TraceGraph) {
        self.graph = graph
        // The container needs its own unique, stable ID.
        super.init(id: UUID())
    }

    /// This is the core synchronization method. It rebuilds the node hierarchy to match the model.
    ///
    /// Call this method whenever the trace graph's topology changes.
    func syncChildNodesFromModel(canvasLayers: [CanvasLayer]) {
          self.children.removeAll()

          // 1. Create a TraceNode for every edge in the graph's engine state.
          for edge in graph.engine.currentState.edges.values {
              let traceNode = TraceNode(edgeID: edge.id, graph: graph)
              
              // 2. Resolve the color for this specific trace node.
              //    This is the "lookup like we do in footprint node" pattern.
              if let layerId = traceNode.layerId,
                 let layer = canvasLayers.first(where: { $0.id == layerId }) {
                  traceNode.color = layer.color
              } else {
                  // Fallback color if the layer is not found (e.g., it's hidden).
                  traceNode.color = NSColor.darkGray.cgColor
              }
              
              self.addChild(traceNode)
          }
          
          self.onNeedsRedraw?()
      }
    
    /// Overridden to ensure that marquee selection can find the selectable child nodes within this container.
    override func nodes(intersecting rect: CGRect) -> [BaseNode] {
        var foundNodes: [BaseNode] = []
        
        // Since the TraceGraphNode itself isn't selectable, we bypass
        // checking it and go straight to its children.
        for child in children where child.isVisible {
            // We call the base implementation on each child, allowing them to be found.
            foundNodes.append(contentsOf: child.nodes(intersecting: rect))
        }
        
        return foundNodes
    }
}
