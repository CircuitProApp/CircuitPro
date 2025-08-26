//
//  ConnectPointsTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation
import CoreGraphics

struct ConnectPointsTransaction: GraphTransaction {
    let start: CGPoint
    let end: CGPoint
    let strategy: ConnectVerticesTransaction.Strategy

    mutating func apply(to state: inout GraphState) -> Set<UUID> {
        let aID = getOrCreateVertex(at: start, state: &state)
        let bID = getOrCreateVertex(at: end, state: &state)
        guard let a = state.vertices[aID], let b = state.vertices[bID] else { return [] }

        var affected: Set<UUID> = [aID, bID]

        if a.point.x == b.point.x || a.point.y == b.point.y {
            affected.formUnion(state.connectStraight(from: a, to: b))
        } else {
            let corner = (strategy == .hThenV)
                ? CGPoint(x: b.point.x, y: a.point.y)
                : CGPoint(x: a.point.x, y: b.point.y)
            let cornerID = state.findVertex(at: corner)?.id
                ?? state.addVertex(at: corner, ownership: .free).id
            if let c = state.vertices[cornerID] {
                affected.insert(cornerID)
                affected.formUnion(state.connectStraight(from: a, to: c))
                affected.formUnion(state.connectStraight(from: c, to: b))
            }
        }

        return affected
    }

    // — Helpers —

    private func getOrCreateVertex(at point: CGPoint, state: inout GraphState) -> UUID {
        if let v = state.findVertex(at: point) { return v.id }
        if let e = state.findEdge(at: point) {
            return state.splitEdge(e.id, at: point, ownership: .free)
                ?? state.addVertex(at: point, ownership: .free).id
        }
        return state.addVertex(at: point, ownership: .free).id
    }
}
