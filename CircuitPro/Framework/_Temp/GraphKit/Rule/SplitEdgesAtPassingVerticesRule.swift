import Foundation
import CoreGraphics

struct SplitEdgesAtPassingVerticesRule: GraphRule {
    func apply(state: inout GraphState, context: ResolutionContext) {
        let tol = context.geometry.epsilon

        // Snapshot edges and vertices first to avoid concurrent mutation issues
        let edges = Array(state.edges.values)
        let verts = Array(state.vertices.values)

        for e in edges {
            guard let p1 = state.vertices[e.start]?.point,
                  let p2 = state.vertices[e.end]?.point else { continue }

            // Skip if edge AABB doesn't intersect neighborhood (cheap locality)
            let edgeRect = CGRect(
                x: min(p1.x, p2.x),
                y: min(p1.y, p2.y),
                width: abs(p2.x - p1.x),
                height: abs(p2.y - p1.y)
            )
            if !edgeRect.intersects(context.neighborhood) { continue }

            // Collect all intermediate vertices on this edge (excluding endpoints)
            var mids: [GraphVertex] = []
            mids.reserveCapacity(2)

            for v in verts where v.id != e.start && v.id != e.end {
                if state.isPoint(v.point, onSegmentBetween: p1, p2: p2, tol: tol) {
                    // Exclude exact endpoints by distance check
                    let d1 = hypot(v.point.x - p1.x, v.point.y - p1.y)
                    let d2 = hypot(v.point.x - p2.x, v.point.y - p2.y)
                    if d1 > tol && d2 > tol {
                        mids.append(v)
                    }
                }
            }
            guard !mids.isEmpty else { continue }

            // Sort mids along the segment by param t
            let (dx, dy) = (p2.x - p1.x, p2.y - p1.y)
            let len2 = max(dx*dx + dy*dy, tol*tol)
            mids.sort { lhs, rhs in
                let tL = ((lhs.point.x - p1.x) * dx + (lhs.point.y - p1.y) * dy) / len2
                let tR = ((rhs.point.x - p1.x) * dx + (rhs.point.y - p1.y) * dy) / len2
                return tL < tR
            }

            // Rebuild as chain: start -> mids... -> end
            if state.edges[e.id] != nil {
                state.removeEdge(e.id)
                var prev = e.start
                for m in mids {
                    _ = state.addEdge(from: prev, to: m.id)
                    prev = m.id
                }
                _ = state.addEdge(from: prev, to: e.end)
            }
        }
    }
}
