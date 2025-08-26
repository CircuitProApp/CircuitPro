//
//  GetOrCreatePinVertexTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct GetOrCreatePinVertexTransaction: GraphTransaction {
    let point: CGPoint
    let ownerID: UUID
    let pinID: UUID
    private(set) var vertexID: WireVertex.ID?

    mutating func apply(to state: inout GraphState) -> Set<WireVertex.ID> {
        let ownership: VertexOwnership = .pin(ownerID: ownerID, pinID: pinID)

        if let v = state.findVertex(at: point) {
            var vv = v
            vv.ownership = ownership
            state.vertices[vv.id] = vv
            vertexID = vv.id
            return [vv.id]
        }

        if let e = state.findEdge(at: point) {
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
