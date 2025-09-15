import Foundation
import CoreGraphics

struct CollapseLinearRunsRule: GraphRule {
    func apply(state: inout GraphState, context: ResolutionContext) {
        let tol = context.geometry.epsilon

        // Seed set: epicenter + 1-hop neighbors to catch survivors of merges
        var seeds = context.epicenter
        for id in context.epicenter {
            for nid in state.neighbors(of: id) { seeds.insert(nid) }
        }

        // Scope to neighborhood AABB to keep this local
        let scopedSeeds: [UUID] = seeds.compactMap { id in
            guard let p = state.vertices[id]?.point else { return nil }
            return context.neighborhood.contains(p) ? id : nil
        }

        for id in scopedSeeds {
            guard let center = state.vertices[id] else { continue }
            // Skip runs starting on protected vertices (e.g., pins), defer to policy
            if context.policy?.isProtected(center, state: state) ?? false { continue }

            // Derive unique incident directions from center
            let dirs = uniqueIncidentDirections(of: center, tol: tol, state: state)

            for dir in dirs {
                processRun(from: center.id, baseDir: dir, tol: tol, context: context, state: &state)
            }
        }
    }

    // Collect unique incident directions (unit vectors) from a vertex
    private func uniqueIncidentDirections(of v: GraphVertex, tol: CGFloat, state: GraphState) -> [CGVector] {
        guard let eids = state.adjacency[v.id] else { return [] }
        var out: [CGVector] = []

        for eid in eids {
            guard let e = state.edges[eid] else { continue }
            let nid = (e.start == v.id) ? e.end : e.start
            guard let n = state.vertices[nid] else { continue }
            let dx = n.point.x - v.point.x, dy = n.point.y - v.point.y
            let len = hypot(dx, dy)
            if len <= tol { continue }
            let dir = CGVector(dx: dx/len, dy: dy/len)

            if !out.contains(where: { approxSameDir($0, dir, tol: tol) }) {
                out.append(dir)
            }
        }
        return out
    }

    private func approxSameDir(_ a: CGVector, _ b: CGVector, tol: CGFloat) -> Bool {
        let dot = a.dx * b.dx + a.dy * b.dy
        return abs(abs(dot) - 1.0) <= 10 * tol
    }

    private func processRun(from startID: UUID, baseDir: CGVector, tol: CGFloat, context: ResolutionContext, state: inout GraphState) {
        guard let startV = state.vertices[startID] else { return }

        // 1) Collect the run as before
        var run: [GraphVertex] = []
        var stack: [UUID] = [startV.id]
        var seen: Set<UUID> = [startV.id]
        while let vid = stack.popLast() {
            guard let v = state.vertices[vid] else { continue }
            run.append(v)
            for nid in state.neighbors(of: vid) {
                guard !seen.contains(nid), let n = state.vertices[nid] else { continue }
                if isOnLine(a: startV.point, dir: baseDir, p: n.point, tol: tol) {
                    seen.insert(nid)
                    stack.append(nid)
                }
            }
        }
        if run.count < 3 { return }

        // 2) Precompute projection t for ordering and for interval tests
        let a = startV.point
        let dir = baseDir
        let denom = max(dir.dx*dir.dx + dir.dy*dir.dy, tol*tol)

        func t(_ p: CGPoint) -> CGFloat {
            return ((p.x - a.x) * dir.dx + (p.y - a.y) * dir.dy) / denom
        }

        // Sort run along the line
        run.sort { lhs, rhs in t(lhs.point) < t(rhs.point) }

        // 3) Build helpers to know which edges lie on the run and their span in t-space
        let runIDs = Set(run.map { $0.id })
        struct SpanEdge { let edge: GraphEdge; let tMin: CGFloat; let tMax: CGFloat }

        var edgesOnRun: [SpanEdge] = []
        for e in state.edges.values {
            guard runIDs.contains(e.start), runIDs.contains(e.end),
                  let p1 = state.vertices[e.start]?.point,
                  let p2 = state.vertices[e.end]?.point,
                  isOnLine(a: a, dir: dir, p: p1, tol: tol),
                  isOnLine(a: a, dir: dir, p: p2, tol: tol)
            else { continue }
            let t1 = t(p1), t2 = t(p2)
            edgesOnRun.append(.init(edge: e, tMin: min(t1, t2), tMax: max(t1, t2)))
        }

        // 4) Decide which vertices to keep (protect, junction/corner, or seam)
        var keep: Set<UUID> = []
        for v in run {
            if context.policy?.isProtected(v, state: state) ?? false {
                keep.insert(v.id)
                continue
            }

            // Degree/junction test same as before
            let deg = state.adjacency[v.id]?.count ?? 0
            let collinearDeg = (state.adjacency[v.id] ?? []).reduce(0) { acc, eid in
                guard let e = state.edges[eid] else { return acc }
                let nid = (e.start == v.id) ? e.end : e.start
                guard let n = state.vertices[nid] else { return acc }
                return acc + (isOnLine(a: v.point, dir: dir, p: n.point, tol: tol) ? 1 : 0)
            }
            if deg > collinearDeg {
                keep.insert(v.id)
                continue
            }

            // NEW: Only pass edges from the run into the seam policy
            let vT = t(v.point)
            let incidentRunEdges = edgesOnRun.filter { se in
                // Edge is incident to v if its span touches vT within tolerance
                (abs(se.tMin - vT) <= 10*tol) || (abs(se.tMax - vT) <= 10*tol)
            }.map { $0.edge }

            if context.edgePolicy?.shouldPreserveVertex(v, connecting: incidentRunEdges) ?? false {
                keep.insert(v.id)
                continue
            }
        }

        // Always keep endpoints in sorted order
        if let first = run.first { keep.insert(first.id) }
        if let last = run.last { keep.insert(last.id) }

        if keep.count >= run.count { return }

        // 5) Remove all run edges and drop non-kept vertices
        let edgesToDelete = Set(edgesOnRun.map { $0.edge })
        for e in edgesToDelete {
            state.removeEdge(e.id)
        }
        for v in run where !keep.contains(v.id) {
            state.removeVertex(v.id)
        }

        // 6) Rebuild chain between consecutive kept vertices
        let keptVerts = run.filter { keep.contains($0.id) }
        guard keptVerts.count >= 2 else { return }

        // Precompute kept t’s for interval queries
        let keptT: [CGFloat] = keptVerts.map { t($0.point) }

        for i in 0..<(keptVerts.count - 1) {
            let vA = keptVerts[i], vB = keptVerts[i+1]
            let tA = keptT[i], tB = keptT[i+1]
            let lo = min(tA, tB) - 10*tol
            let hi = max(tA, tB) + 10*tol

            if let newEdge = state.addEdge(from: vA.id, to: vB.id) {
                // NEW: Propagate ONLY from edges whose spans are within this segment
                let contributing = edgesOnRun
                    .filter { $0.tMin >= lo && $0.tMax <= hi }
                    .map { $0.edge }

                // If empty due to precision, fall back to any overlapping edge
                let contributingFallback = contributing.isEmpty
                    ? edgesOnRun.filter { $0.tMax >= lo && $0.tMin <= hi }.map { $0.edge }
                    : contributing

                context.edgePolicy?.propagateMetadata(from: contributingFallback, to: newEdge)
            }
        }
    }
    private func isOnLine(a: CGPoint, dir: CGVector, p: CGPoint, tol: CGFloat) -> Bool {
        let vx = p.x - a.x, vy = p.y - a.y
        let cross = dir.dx * vy - dir.dy * vx
        let scale = max(hypot(dir.dx, dir.dy), tol)
        return abs(cross) <= tol * scale
    }
}

extension GraphEdge {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
