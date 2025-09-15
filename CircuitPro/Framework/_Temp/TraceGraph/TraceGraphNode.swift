// In: Framework/_Temp/TraceGraph/TraceGraphNode.swift

import AppKit
import Observation

@Observable
final class TraceGraphNode: BaseNode {

    let graph: TraceGraph
    override var isSelectable: Bool { false }

    init(graph: TraceGraph) {
        self.graph = graph
        super.init(id: UUID())
    }

    /// This is the core synchronization method. It rebuilds the node hierarchy to match the model.
    ///
    /// Call this method whenever the trace graph's topology changes.
    func syncChildNodesFromModel(canvasLayers: [CanvasLayer]) {
        
        // --- THIS IS THE FIX ---

        // 1. Create a temporary, unsorted array of all the trace nodes.
        //    Do NOT add them as children yet.
        var unsortedNodes: [TraceNode] = []
        for edge in graph.engine.currentState.edges.values {
            let traceNode = TraceNode(edgeID: edge.id, graph: graph)
            
            // Resolve the node's color based on its layerId
            if let layerId = traceNode.layerId,
               let layer = canvasLayers.first(where: { $0.id == layerId }) {
                traceNode.color = layer.color
            } else {
                // Fallback for traces on hidden or non-existent layers
                traceNode.color = NSColor.darkGray.cgColor
            }
            unsortedNodes.append(traceNode)
        }
        
        // 2. Sort the temporary array based on the layer order.
        //    The `canvasLayers` array is the "source of truth" for stacking order.
        //    We find the index of each node's layer in that array and sort by it.
        let sortedNodes = unsortedNodes.sorted { (nodeA, nodeB) -> Bool in
            // Find the stackup index for node A's layer. Default to a low number (-1) if not found.
            let indexA = canvasLayers.firstIndex(where: { $0.id == nodeA.layerId }) ?? -1
            
            // Find the stackup index for node B's layer.
            let indexB = canvasLayers.firstIndex(where: { $0.id == nodeB.layerId }) ?? -1
            
            // A node with a lower layer index should come first in the array (be drawn earlier).
            return indexA < indexB
        }

        // 3. Clear the old children and add the new, correctly sorted nodes.
        self.children.removeAll()
        for node in sortedNodes {
            self.addChild(node)
        }
        
        self.onNeedsRedraw?()
    }
    
    override func nodes(intersecting rect: CGRect) -> [BaseNode] {
        var foundNodes: [BaseNode] = []
        
        for child in children where child.isVisible {
            foundNodes.append(contentsOf: child.nodes(intersecting: rect))
        }
        
        return foundNodes
    }
}
