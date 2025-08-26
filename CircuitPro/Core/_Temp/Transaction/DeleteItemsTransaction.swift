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
                neighborsCollinear(of: v, state: state).forEach { verticesToCheck.insert($0) }
                state.removeVertex(id)
            }
        }

        return verticesToCheck
    }

    private func neighborsCollinear(of v: WireVertex, state: GraphState) -> [UUID] {
        guard let eids = state.adjacency[v.id] else { return [] }
        var ids: [UUID] = []
        for eid in eids {
            guard let e = state.edges[eid] else { continue }
            let nid = (e.start == v.id) ? e.end : e.start
            guard let n = state.vertices[nid] else { continue }
            if abs(n.point.x - v.point.x) < 1e-6 || abs(n.point.y - v.point.y) < 1e-6 {
                ids.append(nid)
            }
        }
        return ids
    }
}


