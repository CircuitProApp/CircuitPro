// GetOrCreatePinVertexTransaction.swift
import CoreGraphics
import Foundation

struct GetOrCreatePinVertexTransaction: GraphTransaction {
    let point: CGPoint
    let ownerID: UUID
    let pinID: UUID
    private(set) var vertexID: GraphVertex.ID?

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<GraphVertex.ID> {
        let tol = context.tol
        let ownership: VertexOwnership = .pin(ownerID: ownerID, pinID: pinID)

        if let v = state.findVertex(at: point, tol: tol) {
            var vv = v
            vv.ownership = ownership
            state.vertices[vv.id] = vv
            vertexID = vv.id
            return [vv.id]
        }

        if let e = state.findEdge(at: point, tol: tol) {
            if let id = state.splitEdge(e.id, at: point, ownership: ownership) {
                vertexID = id
                return [id]
            } else {
                return []
            }
        }

        let v = state.addVertex(at: point, ownership: ownership)
        vertexID = v.id
        return [v.id]
    }
}
