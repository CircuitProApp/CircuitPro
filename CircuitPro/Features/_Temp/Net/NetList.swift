//
//  Netlist.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/3/25.
//

import Foundation
import CoreGraphics

// 1. NodeKind
// Defines the semantic role of a point in the graph, which dictates its appearance.
enum NodeKind {
    case endpoint // A terminal point of a wire.
    case junction // An electrical connection (T-junction or X-junction).
}

// 2. Node
// A specific, identifiable point in the schematic.
struct Node: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
    var kind: NodeKind
}

// 3. Edge
// Represents a straight, axis-aligned wire segment between two nodes.
struct Edge: Identifiable, Hashable {
    let id: UUID
    var a: UUID // The ID of the starting Node.
    var b: UUID // The ID of the ending Node.
}

// 4. Net
// Represents a single, fully connected electrical net, composed of nodes and edges.
struct Net: Identifiable, Hashable {
    let id: UUID
    var nodeByID: [UUID: Node] = [:]
    var edges: [Edge] = []
}

extension Net {
    
    // Merges consecutive horizontal or vertical edges by deleting the
    // intermediate node when that node is not a junction.
    mutating func mergeColinearEdges() {
        // 1. Build an adjacency list.
        func rebuildAdjacency() -> [UUID: [Edge]] {
            var adj: [UUID: [Edge]] = [:]
            for e in edges {
                adj[e.a, default: []].append(e)
                adj[e.b, default: []].append(e)
            }
            return adj
        }
        
        var adjacency = rebuildAdjacency()
        var changed = true
        
        // 2. Iterate until no more collapses are possible.
        while changed {
            changed = false
            for (nodeID, connected) in adjacency {
                
                // 2.1 The node must be non-junction and have exactly two neighbours.
                guard connected.count == 2,
                      let node = nodeByID[nodeID],
                      node.kind != .junction else { continue }
                
                let e1 = connected[0]
                let e2 = connected[1]
                
                // 2.2 Identify the “other” endpoints of the two edges.
                let other1ID = (e1.a == nodeID ? e1.b : e1.a)
                let other2ID = (e2.a == nodeID ? e2.b : e2.a)
                
                guard other1ID != other2ID,
                      let p0 = nodeByID[other1ID]?.point,
                      let p1 = node.point as CGPoint?,
                      let p2 = nodeByID[other2ID]?.point else { continue }
                
                // 2.3 Must be perfectly horizontal or vertical.
                let horizontal = (p0.y == p1.y) && (p1.y == p2.y)
                let vertical   = (p0.x == p1.x) && (p1.x == p2.x)
                guard horizontal || vertical else { continue }
                
                // 2.4 Collapse: remove the node and its two edges, add one new edge.
                edges.removeAll { $0.id == e1.id || $0.id == e2.id }
                nodeByID.removeValue(forKey: nodeID)
                let newEdge = Edge(id: UUID(), a: other1ID, b: other2ID)
                edges.append(newEdge)
                
                // 2.5 Rebuild adjacency and restart scanning.
                adjacency = rebuildAdjacency()
                changed = true
                break
            }
        }
    }
}

extension Net {

    // 1. Helper
    private func hasNode(at p: CGPoint, tolerance: CGFloat = 0.5) -> Bool {
        nodeByID.values.contains { abs($0.point.x - p.x) < tolerance &&
                                   abs($0.point.y - p.y) < tolerance }
    }

    // 2. New signature (old one remains a thin wrapper)
    static func findAndMergeIntentionalIntersections(
        between netA: inout Net,
        and netB: inout Net) -> Bool
    {
        var intersections: [(edgeA: UUID, edgeB: UUID, p: CGPoint)] = []

        // 2.1 Scan geometry
        for edgeA in netA.edges {
            guard let a0 = netA.nodeByID[edgeA.a], let a1 = netA.nodeByID[edgeA.b] else { continue }
            let segA = LineSegment(start: a0.point, end: a1.point)

            for edgeB in netB.edges {
                guard let b0 = netB.nodeByID[edgeB.a], let b1 = netB.nodeByID[edgeB.b] else { continue }
                let segB = LineSegment(start: b0.point, end: b1.point)

                if let p = segA.intersectionPoint(with: segB) {
                    // 2.2 Keep only intersections that sit on a real node
                    if netA.hasNode(at: p) || netB.hasNode(at: p) {
                        intersections.append((edgeA.id, edgeB.id, p))
                    }
                }
            }
        }

        guard !intersections.isEmpty else { return false }

        // 2.3 Perform splits (identical to previous implementation)
        for i in intersections {
            let nID = netA.splitEdge(withID: i.edgeA, at: i.p)
            if let nID = nID,
               let idx = netB.edges.firstIndex(where: { $0.id == i.edgeB }),
               let nb0 = netB.nodeByID[netB.edges[idx].a],
               let nb1 = netB.nodeByID[netB.edges[idx].b] {

                let e1 = Edge(id: UUID(), a: nb0.id, b: nID)
                let e2 = Edge(id: UUID(), a: nID,  b: nb1.id)
                netB.edges.remove(at: idx)
                netB.edges.append(contentsOf: [e1, e2])
            }
        }
        return true
    }

    // 3. Legacy shim (keeps old call-sites working, if any)
    static func findAndMergeIntersections(
        between netA: inout Net,
        and netB: inout Net) -> Bool
    {
        findAndMergeIntentionalIntersections(between: &netA, and: &netB)
    }
}
