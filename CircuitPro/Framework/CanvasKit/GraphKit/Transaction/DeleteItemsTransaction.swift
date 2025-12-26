//
//  DeleteItemsTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct DeleteItemsTransaction: GraphTransaction {
    let items: Set<UUID>

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        var verticesToCheck: Set<UUID> = []
        for id in items {
            if let e = state.edges[id] {
                verticesToCheck.insert(e.start)
                verticesToCheck.insert(e.end)
                state.removeEdge(id)
            }
        }
        for id in items {
            if let v = state.vertices[id] {
                for nid in neighborsCollinear(of: v, state: state, tol: context.tolerance) {
                    verticesToCheck.insert(nid)
                }
                state.removeVertex(id)
            }
        }
        return verticesToCheck
    }

    private func neighborsCollinear(of v: GraphVertex, state: GraphState, tol: CGFloat) -> [UUID] {
        return state.neighbors(of: v.id).filter { nid in
            guard let n = state.vertices[nid] else { return false }
            return abs(n.point.x - v.point.x) < tol || abs(n.point.y - v.point.y) < tol
        }
    }
}
