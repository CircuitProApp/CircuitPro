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

    func syncChildNodesFromModel(canvasLayers: [CanvasLayer]) {
        var unsortedNodes: [TraceNode] = []
        for edge in graph.engine.currentState.edges.values {
            let traceNode = TraceNode(edgeID: edge.id, graph: graph)
            
            if let layerId = traceNode.layerId,
               let layer = canvasLayers.first(where: { $0.id == layerId }) {
                traceNode.color = layer.color
            } else {
                traceNode.color = NSColor.darkGray.cgColor
            }
            unsortedNodes.append(traceNode)
        }
        
        let sortedNodes = unsortedNodes.sorted { (nodeA, nodeB) -> Bool in
            let indexA = canvasLayers.firstIndex(where: { $0.id == nodeA.layerId }) ?? -1
            let indexB = canvasLayers.firstIndex(where: { $0.id == nodeB.layerId }) ?? -1
            return indexA < indexB
        }

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
    
    // --- MODIFIED: This is the halo merging logic, adapted from SchematicGraphNode ---
    override func makeHaloPath(context: RenderContext) -> CGPath? {
        // 1. Find which of our children are `TraceNode`s and are also highlighted.
        let selectedTraces = self.children.compactMap { child -> TraceNode? in
            guard context.highlightedNodeIDs.contains(child.id) else { return nil }
            return child as? TraceNode
        }
        
        guard !selectedTraces.isEmpty else { return nil }

        // 2. Create a path for the center-lines and determine the max width.
        let compositePath = CGMutablePath()
        var maxWidth: CGFloat = 0.0

        for traceNode in selectedTraces {
            guard let edge = graph.engine.currentState.edges[traceNode.edgeID],
                  let startVertex = graph.engine.currentState.vertices[edge.start],
                  let endVertex = graph.engine.currentState.vertices[edge.end] else {
                continue
            }
            
            // Add the segment to the path
            compositePath.move(to: startVertex.point)
            compositePath.addLine(to: endVertex.point)
            
            // Keep track of the maximum width of all selected traces
            if let metadata = graph.edgeMetadata[traceNode.edgeID] {
                maxWidth = max(maxWidth, metadata.width)
            }
        }

        // 3. Stroke the path with a width relative to the content.
        if !compositePath.isEmpty {
            // The halo width is now the largest trace's width plus a fixed padding.
            // This ensures it's always visible and proportional.
            let haloPadding: CGFloat = 2.0 // A reasonable visual padding in points
            let haloWidth = maxWidth + haloPadding
            
            return compositePath.copy(strokingWithWidth: haloWidth, lineCap: .round, lineJoin: .round, miterLimit: 0)
        }
        
        return nil
    }
}
