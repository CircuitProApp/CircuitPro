//
//  MoveVertexTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//


import Foundation
// Move a single vertex to a new position (used by syncPins)
struct MoveVertexTransaction: GraphTransaction {
    let id: UUID
    let newPoint: CGPoint

    mutating func apply(to state: inout GraphState) -> Set<UUID> {
        if var v = state.vertices[id] {
            v.point = newPoint
            state.vertices[id] = v
            return [id]
        }
        return []
    }
}
