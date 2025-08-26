import Foundation
import CoreGraphics

struct CollapseCollinearRunsRule: GraphRule {
    func apply(state: inout GraphState, context: ResolutionContext) {
        let tol = context.grid.epsilon

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
                processRun(from: center.id, baseDir: dir, tol: tol, policy: context.policy, state: &state)
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

            // Deduplicate directions by angle (within tol)
            if !out.contains(where: { approxSameDir($0, dir, tol: tol) }) {
                out.append(dir)
            }
        }
        return out
    }

    private func approxSameDir(_ a: CGVector, _ b: CGVector, tol: CGFloat) -> Bool {
        // Consider opposite directions as the same line direction
        let dot = a.dx * b.dx + a.dy * b.dy
        // dot ~ 1 or ~ -1 within tolerance
        return abs(abs(dot) - 1.0) <= 10 * tol
    }

    // Grow a line run through the graph along baseDir (both directions), then collapse it
    private func processRun(from startID: UUID, baseDir: CGVector, tol: CGFloat, policy: VertexPolicy?, state: inout GraphState) {
        guard let startV = state.vertices[startID] else { return }

        // BFS/DFS collecting vertices collinear with baseDir
        var run: [GraphVertex] = []
        var stack: [UUID] = [startV.id]
        var seen: Set<UUID> = [startV.id]

        while let vid = stack.popLast() {
            guard let v = state.vertices[vid] else { continue }
            run.append(v)

            for nid in state.neighbors(of: vid) {
                guard !seen.contains(nid), let n = state.vertices[nid] else { continue }
                // Check if neighbor is collinear with the line through startV in baseDir
                if isOnLine(a: startV.point, dir: baseDir, p: n.point, tol: tol) {
                    seen.insert(nid)
                    stack.append(nid)
                }
            }
        }
        if run.count < 3 { return }

        // Decide which vertices to keep
        var keep: Set<UUID> = []
        for v in run {
            if policy?.isProtected(v, state: state) ?? false {
                keep.insert(v.id)
                continue
            }
            // Degree within the run's line direction (collinear degree)
            let deg = state.adjacency[v.id]?.count ?? 0
            let collinearDeg = (state.adjacency[v.id] ?? []).reduce(0) { acc, eid in
                guard let e = state.edges[eid] else { return acc }
                let nid = (e.start == v.id) ? e.end : e.start
                guard let n = state.vertices[nid] else { return acc }
                return acc + (isOnLine(a: v.point, dir: baseDir, p: n.point, tol: tol) ? 1 : 0)
            }
            if deg > collinearDeg { keep.insert(v.id) } // branching or corner in/out of the run
        }

        // Sort run along the line by projection param t and keep endpoints
        let a = startV.point
        let dir = baseDir
        let denom = max(dir.dx*dir.dx + dir.dy*dir.dy, tol*tol)

        run.sort { lhs, rhs in
            let tL = ((lhs.point.x - a.x) * dir.dx + (lhs.point.y - a.y) * dir.dy) / denom
            let tR = ((rhs.point.x - a.x) * dir.dx + (rhs.point.y - a.y) * dir.dy) / denom
            return tL < tR
        }
        if let first = run.first { keep.insert(first.id) }
        if let last = run.last { keep.insert(last.id) }

        // If nothing to collapse, return
        if keep.count >= run.count { return }

        // Remove internal edges among the run
        let runIDs = Set(run.map { $0.id })
        for v in run {
            if let eids = state.adjacency[v.id] {
                for eid in Array(eids) {
                    guard let e = state.edges[eid] else { continue }
                    let other = (e.start == v.id) ? e.end : e.start
                    if runIDs.contains(other) {
                        state.removeEdge(eid)
                    }
                }
            }
        }

        // Remove removable vertices
        for v in run where !keep.contains(v.id) {
            state.removeVertex(v.id)
        }

        // Reconnect the kept vertices in order
        let keptVerts = run.filter { keep.contains($0.id) }
        guard keptVerts.count >= 2 else { return }
        for i in 0..<(keptVerts.count - 1) {
            _ = state.addEdge(from: keptVerts[i].id, to: keptVerts[i+1].id)
        }
    }

    // Test if point p lies on the infinite line passing through a in direction dir
    private func isOnLine(a: CGPoint, dir: CGVector, p: CGPoint, tol: CGFloat) -> Bool {
        let vx = p.x - a.x, vy = p.y - a.y
        let cross = dir.dx * vy - dir.dy * vx
        // Normalize tol by |dir| (we use |dir| ~ 1 for unit, but be safe)
        let scale = max(hypot(dir.dx, dir.dy), tol)
        return abs(cross) <= tol * scale
    }
}
