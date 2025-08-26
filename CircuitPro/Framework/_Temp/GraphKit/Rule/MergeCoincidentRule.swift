//
//  MergeCoincidentRule.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation
import CoreGraphics

struct MergeCoincidentRule: GraphRule {
    func apply(state: inout GraphState, context: ResolutionContext) {
        let tol = context.grid.epsilon

        var processed: Set<UUID> = []
        var buckets: [String: [GraphVertex]] = [:]
        for v in state.vertices.values {
            let key = bucketKey(v.point, tol: tol)
            buckets[key, default: []].append(v)
        }

        for bucketVerts in buckets.values {
            guard bucketVerts.count > 1 else { continue }
            var remaining = bucketVerts
            while let v = remaining.popLast() {
                if processed.contains(v.id) { continue }
                var cluster = [v]
                var i = 0
                while i < remaining.count {
                    let u = remaining[i]
                    if hypot(v.point.x - u.point.x, v.point.y - u.point.y) < tol {
                        cluster.append(u)
                        remaining.remove(at: i)
                    } else {
                        i += 1
                    }
                }
                guard cluster.count > 1 else { continue }

                let survivor = context.policy?.preferSurvivor(cluster, state: state) ?? cluster[0]
                processed.insert(survivor.id)

                for victim in cluster where victim.id != survivor.id {
                    rewireEdges(from: victim.id, to: survivor.id, state: &state)
                    state.removeVertex(victim.id)
                    processed.insert(victim.id)
                }
            }
        }
    }

    private func bucketKey(_ p: CGPoint, tol: CGFloat) -> String {
        let qx = (p.x / tol).rounded(.toNearestOrEven)
        let qy = (p.y / tol).rounded(.toNearestOrEven)
        return "\(qx)|\(qy)"
    }

    private func rewireEdges(from oldID: UUID, to newID: UUID, state: inout GraphState) {
        guard let eids = state.adjacency[oldID] else { return }
        for eid in eids {
            guard let e = state.edges[eid] else { continue }
            let other = (e.start == oldID) ? e.end : e.start
            if other == newID { continue }
            _ = state.addEdge(from: newID, to: other)
        }
    }
}
