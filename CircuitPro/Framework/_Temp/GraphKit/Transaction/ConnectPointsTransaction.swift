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

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        let tol = context.tol
        let aID = getOrCreateVertex(at: start, state: &state, tol: tol)
        let bID = getOrCreateVertex(at: end, state: &state, tol: tol)
        guard let a = state.vertices[aID], let b = state.vertices[bID] else { return [] }

        var affected: Set<UUID> = [aID, bID]

        if abs(a.point.x - b.point.x) < tol || abs(a.point.y - b.point.y) < tol {
            affected.formUnion(state.connectStraight(from: a, to: b, tol: tol))
        } else {
            let corner = (strategy == .hThenV)
                ? CGPoint(x: b.point.x, y: a.point.y)
                : CGPoint(x: a.point.x, y: b.point.y)
            let cornerID = state.findVertex(at: corner, tol: tol)?.id
                ?? state.addVertex(at: corner).id
            if let c = state.vertices[cornerID] {
                affected.insert(cornerID)
                affected.formUnion(state.connectStraight(from: a, to: c, tol: tol))
                affected.formUnion(state.connectStraight(from: c, to: b, tol: tol))
            }
        }
        return affected
    }

    private func getOrCreateVertex(at point: CGPoint, state: inout GraphState, tol: CGFloat) -> UUID {
        if let v = state.findVertex(at: point, tol: tol) { return v.id }
        if let e = state.findEdge(at: point, tol: tol) {
            return state.splitEdge(e.id, at: point)
                ?? state.addVertex(at: point).id
        }
        return state.addVertex(at: point).id
    }
}
