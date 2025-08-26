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
            connectStraight(from: a, to: b, affected: &affected, state: &state)
        } else {
            let corner = (strategy == .hThenV)
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

    // — Helpers —

    private func getOrCreateVertex(at point: CGPoint, state: inout GraphState) -> UUID {
        if let v = state.findVertex(at: point) { return v.id }
        if let e = state.findEdge(at: point) {
            return split(edgeID: e.id, at: point, ownership: .free, state: &state)!
        }
        return state.addVertex(at: point, ownership: .free).id
    }

    @discardableResult
    private func split(edgeID: UUID, at point: CGPoint, ownership: VertexOwnership, state: inout GraphState) -> UUID? {
        guard let e = state.edges[edgeID] else { return nil }
        let startID = e.start, endID = e.end
        let originalNetID = state.vertices[startID]?.netID

        state.removeEdge(edgeID)
        let newV = state.addVertex(at: point, ownership: ownership, netID: originalNetID)
        _ = state.addEdge(from: startID, to: newV.id)
        _ = state.addEdge(from: newV.id, to: endID)
        return newV.id
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
