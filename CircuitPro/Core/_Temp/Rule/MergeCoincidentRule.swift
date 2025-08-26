//
//  MergeCoincidentRule.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//


import Foundation
import CoreGraphics

struct MergeCoincidentRule: GraphRule {
    private let tol: CGFloat = 1e-6

    func apply(state: inout GraphState, context: ResolutionContext) {
        // Collect candidate vertices (global for now; you can scope to a neighborhood later)
        var processed: Set<UUID> = []

        // Simple bucketing by rounded coordinates reduces O(n^2) in common cases.
        var buckets: [String: [WireVertex]] = [:]
        for v in state.vertices.values {
            let key = bucketKey(v.point)
            buckets[key, default: []].append(v)
        }

        for bucketVerts in buckets.values {
            guard bucketVerts.count > 1 else { continue }

            // Within a bucket, group by actual distance < tol
            var remaining = bucketVerts
            while let v = remaining.popLast() {
                if processed.contains(v.id) { continue }
                var group = [v]
                var i = 0
                while i < remaining.count {
                    let u = remaining[i]
                    if hypot(v.point.x - u.point.x, v.point.y - u.point.y) < tol {
                        group.append(u)
                        remaining.remove(at: i)
                    } else {
                        i += 1
                    }
                }
                guard group.count > 1 else { continue }

                let survivor = group.first(where: { if case .pin = $0.ownership { return true } else { return false } }) ?? group[0]
                processed.insert(survivor.id)

                for victim in group where victim.id != survivor.id {
                    rewireEdges(from: victim.id, to: survivor.id, state: &state)
                    state.removeVertex(victim.id)
                    processed.insert(victim.id)
                }
            }
        }
    }

    private func bucketKey(_ p: CGPoint) -> String {
        // 1e-6 bucket; adjust if you adopt a grid policy
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