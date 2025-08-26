//
//  GetOrCreateVertexTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation
import CoreGraphics

struct GetOrCreateVertexTransaction: GraphTransaction {
    let point: CGPoint
    private(set) var createdID: GraphVertex.ID?

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<GraphVertex.ID> {
        let tol = context.tol
        if let v = state.findVertex(at: point, tol: tol) {
            createdID = v.id
            return [v.id]
        }
        if let e = state.findEdge(at: point, tol: tol),
           let id = state.splitEdge(e.id, at: point, ownership: .free) {
            createdID = id
            return [id]
        }
        let v = state.addVertex(at: point, ownership: .free)
        createdID = v.id
        return [v.id]
    }
}

