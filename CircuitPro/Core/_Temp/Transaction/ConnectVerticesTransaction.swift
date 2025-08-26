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
            connectStraight(from: a, to: b, affected: &affected, state: &state)
        } else {
            let corner = strategy == .hThenV
                ? CGPoint(x: b.point.x, y: a.point.y)
                : CGPoint(x: a.point.x, y: b.point.y)
            let cornerID = state.findVertex(at: corner)?.id
                ?? state.addVertex(at: corner, ownership: .free).id
            if let c = state.vertices[cornerID] {
                affected.insert(cornerID)
                connectStraight(from: a, to: c, affected: &affected, state: &state)
                connectStraight(from: c, to: b, affected: &affected, state: &state)
            }
        }
        return affected
    }

    private func connectStraight(from a: WireVertex, to b: WireVertex, affected: inout Set<UUID>, state: inout GraphState) {
        var onPath: [WireVertex] = [a, b]
        let others = state.vertices.values.filter {
            $0.id != a.id && $0.id != b.id &&
            state.isPoint($0.point, onSegmentBetween: a.point, p2: b.point)
        }
        onPath.append(contentsOf: others)
        for v in others { affected.insert(v.id) }
        if a.point.x == b.point.x {
            onPath.sort { $0.point.y < $1.point.y }
        } else {
            onPath.sort { $0.point.x < $1.point.x }
        }
        for i in 0..<(onPath.count - 1) {
            _ = state.addEdge(from: onPath[i].id, to: onPath[i+1].id)
        }
    }
}
