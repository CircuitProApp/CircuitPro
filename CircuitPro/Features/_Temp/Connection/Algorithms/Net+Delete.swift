//
//  Net+Delete.swift
//  CircuitPro
//
//  Created by Codex
//

import Foundation

extension Net {
    /// Returns new nets after removing the edges whose IDs are in `edgeIDs`.
    /// Any orphaned nodes are discarded and the resulting nets are split into
    /// connected components.
    func deletingEdges(withIDs edgeIDs: Set<UUID>) -> [Net] {
        let remainingEdges = edges.filter { !edgeIDs.contains($0.id) }
        guard !remainingEdges.isEmpty else { return [] }

        var usedNodeIDs = Set<UUID>()
        for edge in remainingEdges {
            usedNodeIDs.insert(edge.startNodeID)
            usedNodeIDs.insert(edge.endNodeID)
        }
        var remainingNodes = nodeByID.filter { usedNodeIDs.contains($0.key) }

        // Downgrade junctions that are no longer used as intersections
        var degree: [UUID: Int] = [:]
        for edge in remainingEdges {
            degree[edge.startNodeID, default: 0] += 1
            degree[edge.endNodeID, default: 0] += 1
        }
        for id in remainingNodes.keys {
            if degree[id, default: 0] <= 2 {
                remainingNodes[id]?.kind = .endpoint
            }
        }

        var baseNet = Net(id: UUID(), nodeByID: remainingNodes, edges: remainingEdges)
        baseNet.mergeColinearEdges()
        baseNet.downgradeRedundantJunctions()
        return baseNet.connectedComponents()
    }

    /// Splits the net into connected components.
    func connectedComponents() -> [Net] {
        var visitedNodes = Set<UUID>()
        var components: [Net] = []

        for nodeID in nodeByID.keys {
            guard !visitedNodes.contains(nodeID) else { continue }

            var stack: [UUID] = [nodeID]
            var nodeSet = Set<UUID>()
            var edgeSet = Set<UUID>()
            visitedNodes.insert(nodeID)

            while let current = stack.popLast() {
                nodeSet.insert(current)
                for edge in edges where edge.startNodeID == current || edge.endNodeID == current {
                    if !edgeSet.contains(edge.id) {
                        edgeSet.insert(edge.id)
                        let neighbor = (edge.startNodeID == current) ? edge.endNodeID : edge.startNodeID
                        if !visitedNodes.contains(neighbor) {
                            visitedNodes.insert(neighbor)
                            stack.append(neighbor)
                        }
                    }
                }
            }

            var nodes: [UUID: Node] = [:]
            for id in nodeSet { nodes[id] = nodeByID[id] }
            let compEdges = edges.filter { edgeSet.contains($0.id) }
            components.append(Net(id: UUID(), nodeByID: nodes, edges: compEdges))
        }

        return components
    }
}

