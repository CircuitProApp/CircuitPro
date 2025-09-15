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

        // BFS/DFS collecting vertices collinear with baseDir
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

        // Decide which vertices to keep
        var keep: Set<UUID> = []
        for v in run {
            // Reason 1 to keep: VertexPolicy says it's protected (e.g., a pin).
            if context.policy?.isProtected(v, state: state) ?? false {
                keep.insert(v.id)
                continue
            }
            
            let deg = state.adjacency[v.id]?.count ?? 0
            let collinearDeg = (state.adjacency[v.id] ?? []).reduce(0) { acc, eid in
                guard let e = state.edges[eid] else { return acc }
                let nid = (e.start == v.id) ? e.end : e.start
                guard let n = state.vertices[nid] else { return acc }
                return acc + (isOnLine(a: v.point, dir: baseDir, p: n.point, tol: tol) ? 1 : 0)
            }
            // Reason 2 to keep: It's a T-junction or corner (not just a pass-through).
            if deg > collinearDeg {
                keep.insert(v.id)
                continue
            }

            // --- THIS IS THE FIX ---
            // Reason 3 to keep: EdgePolicy says it's a critical "seam" where metadata changes.
            let edgesInRun = (state.adjacency[v.id] ?? []).compactMap { state.edges[$0] }
            if context.edgePolicy?.shouldPreserveVertex(v, connecting: edgesInRun) ?? false {
                keep.insert(v.id)
                continue
            }
            // --- END FIX ---
        }

        // Sort run along the line by projection param t and always keep endpoints.
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

        // If nothing to collapse, return.
        if keep.count >= run.count { return }

        // --- METADATA PROPAGATION LOGIC ---
        var edgesToDelete: [GraphEdge] = []
        let runIDs = Set(run.map { $0.id })
        for v in run {
            if let eids = state.adjacency[v.id] {
                for eid in eids {
                    guard let e = state.edges[eid] else { continue }
                    let other = (e.start == v.id) ? e.end : e.start
                    if runIDs.contains(other) {
                        edgesToDelete.append(e)
                    }
                }
            }
        }
        edgesToDelete = Array(Set(edgesToDelete))

        for edge in edgesToDelete {
            state.removeEdge(edge.id)
        }

        for v in run where !keep.contains(v.id) {
            state.removeVertex(v.id)
        }

        let keptVerts = run.filter { keep.contains($0.id) }
        guard keptVerts.count >= 2 else { return }
        for i in 0..<(keptVerts.count - 1) {
            if let newEdge = state.addEdge(from: keptVerts[i].id, to: keptVerts[i+1].id) {
                // --- THIS IS THE FIX ---
                // CRITICAL: Inform the formal EdgePolicy so it can transfer metadata.
                context.edgePolicy?.propagateMetadata(from: edgesToDelete, to: newEdge)
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
