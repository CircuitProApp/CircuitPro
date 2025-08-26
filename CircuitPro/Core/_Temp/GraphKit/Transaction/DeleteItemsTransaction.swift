//
//  DeleteItemsTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

// Delete edges/vertices by ID. Returns a neighborhood epicenter for ruleset cleanup.
struct DeleteItemsTransaction: GraphTransaction {
    let items: Set<UUID>

    mutating func apply(to state: inout GraphState) -> Set<UUID> {
        var verticesToCheck: Set<UUID> = []

        // 1) Delete edges first, track endpoints
        for id in items {
            if let e = state.edges[id] {
                verticesToCheck.insert(e.start)
                verticesToCheck.insert(e.end)
                state.removeEdge(id)
            }
        }

        // 2) Then delete vertices, track collinear neighbors
        for id in items {
            if let v = state.vertices[id] {
                for nid in neighborsCollinear(of: v, state: state) {
                    verticesToCheck.insert(nid)
                }
                state.removeVertex(id)
            }
        }

        return verticesToCheck
    }

    // Centralized neighbor traversal via GraphState.neighbors(of:)
    private func neighborsCollinear(of v: WireVertex, state: GraphState) -> [UUID] {
        // Note: still using a literal tolerance; consider threading grid.epsilon later.
        return state.neighbors(of: v.id).filter { nid in
            guard let n = state.vertices[nid] else { return false }
            return abs(n.point.x - v.point.x) < 1e-6 || abs(n.point.y - v.point.y) < 1e-6
        }
    }
}
