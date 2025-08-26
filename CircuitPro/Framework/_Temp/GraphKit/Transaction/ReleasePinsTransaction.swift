//
//  ReleasePinsTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//


import Foundation
// Release all pins owned by a component (turn them into free vertices)
struct ReleasePinsTransaction: GraphTransaction {
    let ownerID: UUID

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        var epicenter: Set<UUID> = []
        for (id, v) in state.vertices {
            if case .pin(let o, _) = v.ownership, o == ownerID {
                var vv = v
                vv.ownership = .free
                state.vertices[id] = vv
                epicenter.insert(id)
            }
        }
        return epicenter
    }
}
