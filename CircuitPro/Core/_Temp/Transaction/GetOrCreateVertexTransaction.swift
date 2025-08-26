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
    private(set) var createdID: WireVertex.ID?

    mutating func apply(to state: inout GraphState) -> Set<WireVertex.ID> {
        if let v = state.findVertex(at: point) {
            createdID = v.id
            return [v.id]
        }

        if let e = state.findEdge(at: point) {
            if let id = split(edgeID: e.id, at: point, ownership: .free, state: &state) {
                createdID = id
                return [id]
            } else {
                return []
            }
        }

        let v = state.addVertex(at: point, ownership: .free)
        createdID = v.id
        return [v.id]
    }

    private func split(edgeID: WireEdge.ID, at point: CGPoint, ownership: VertexOwnership, state: inout GraphState) -> WireVertex.ID? {
        guard let edge = state.edges[edgeID] else { return nil }
        let startID = edge.start
        let endID = edge.end
        let originalNetID = state.vertices[startID]?.netID

        state.removeEdge(edgeID)
        let newV = state.addVertex(at: point, ownership: ownership, netID: originalNetID)
        _ = state.addEdge(from: startID, to: newV.id)
        _ = state.addEdge(from: newV.id, to: endID)
        return newV.id
    }
}

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
            if let id = split(edgeID: e.id, at: point, ownership: ownership, state: &state) {
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

    private func split(edgeID: WireEdge.ID, at point: CGPoint, ownership: VertexOwnership, state: inout GraphState) -> WireVertex.ID? {
        guard let edge = state.edges[edgeID] else { return nil }
        let startID = edge.start
        let endID = edge.end
        let originalNetID = state.vertices[startID]?.netID

        state.removeEdge(edgeID)
        let newV = state.addVertex(at: point, ownership: ownership, netID: originalNetID)
        _ = state.addEdge(from: startID, to: newV.id)
        _ = state.addEdge(from: newV.id, to: endID)
        return newV.id
    }
}
