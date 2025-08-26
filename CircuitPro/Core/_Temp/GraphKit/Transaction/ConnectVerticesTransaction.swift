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

    func apply(to state: inout GraphState) -> Set<UUID> {
        guard let a = state.vertices[startID], let b = state.vertices[endID] else { return [] }
        var affected: Set<UUID> = [a.id, b.id]

        if a.point.x == b.point.x || a.point.y == b.point.y {
            affected.formUnion(state.connectStraight(from: a, to: b))
        } else {
            let corner = strategy == .hThenV
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

}
