//
//  CanvasItemGraphSync.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// Keeps a graph in sync with a list of canvas items without touching non-item nodes/edges.
final class CanvasItemGraphSync {
    private var ownedNodeIDs: Set<NodeID> = []
    private var ownedEdgeIDs: Set<EdgeID> = []

    func sync(items: [any CanvasItem], graph: CanvasGraph) {
        var nextNodeIDs: Set<NodeID> = []
        var nextEdgeIDs: Set<EdgeID> = []

        for item in items {
            switch item.elementID {
            case .node(let nodeID):
                nextNodeIDs.insert(nodeID)
            case .edge(let edgeID):
                nextEdgeIDs.insert(edgeID)
            }
            item.apply(to: graph)
        }

        let removedNodes = ownedNodeIDs.subtracting(nextNodeIDs)
        for nodeID in removedNodes {
            graph.removeNode(nodeID)
        }

        let removedEdges = ownedEdgeIDs.subtracting(nextEdgeIDs)
        for edgeID in removedEdges {
            graph.removeEdge(edgeID)
        }

        ownedNodeIDs = nextNodeIDs
        ownedEdgeIDs = nextEdgeIDs
    }
}
