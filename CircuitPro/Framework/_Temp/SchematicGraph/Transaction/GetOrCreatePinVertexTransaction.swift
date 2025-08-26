// GetOrCreatePinVertexTransaction.swift
// Domain wrapper that ensures a vertex exists at a point and returns its ID.
// Note: Ownership/pin semantics are handled in the WireGraph ownership map,
// not in the core GraphState.

import Foundation
import CoreGraphics

struct GetOrCreatePinVertexTransaction: GraphTransaction {
    let point: CGPoint
    let ownerID: UUID
    let pinID: UUID
    private(set) var vertexID: GraphVertex.ID?

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<GraphVertex.ID> {
        let tol = context.tolerance

        // Try existing vertex at the point
        if let v = state.findVertex(at: point, tol: tol) {
            vertexID = v.id
            return [v.id]
        }

        // If the point lies on an edge, split it
        if let e = state.findEdge(at: point, tol: tol),
           let id = state.splitEdge(e.id, at: point) {
            vertexID = id
            return [id]
        }

        // Otherwise, create a new free vertex
        let v = state.addVertex(at: point)
        vertexID = v.id
        return [v.id]
    }
}
