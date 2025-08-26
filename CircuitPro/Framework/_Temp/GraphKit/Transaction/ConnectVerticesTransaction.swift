//
//  ConnectVerticesTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct ConnectVerticesTransaction: GraphTransaction {
    enum Strategy { case hThenV, vThenH }
    let startID: UUID
    let endID: UUID
    let strategy: Strategy

    func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        let tol = context.tol
        guard let a = state.vertices[startID], let b = state.vertices[endID] else { return [] }
        var affected: Set<UUID> = [a.id, b.id]

        if abs(a.point.x - b.point.x) < tol || abs(a.point.y - b.point.y) < tol {
            affected.formUnion(state.connectStraight(from: a, to: b, tol: tol))
        } else {
            let corner = strategy == .hThenV
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
}
