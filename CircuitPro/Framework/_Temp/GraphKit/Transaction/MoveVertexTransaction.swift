//
//  MoveVertexTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation
import CoreGraphics

// Move a single vertex to a new position (used by syncPins)
struct MoveVertexTransaction: GraphTransaction {
    let id: UUID
    let newPoint: CGPoint
    var snapToGrid: Bool = true

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        guard var v = state.vertices[id] else { return [] }

        let target = snapToGrid ? context.grid.snap(newPoint) : newPoint
        // Skip tiny moves within tolerance
        let dx = v.point.x - target.x
        let dy = v.point.y - target.y
        if (dx*dx + dy*dy).squareRoot() <= context.tolerance { return [] }

        v.point = target
        state.vertices[id] = v
        return [id]
    }
}
