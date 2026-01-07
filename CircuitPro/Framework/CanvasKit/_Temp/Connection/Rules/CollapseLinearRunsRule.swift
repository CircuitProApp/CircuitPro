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

        // Determine candidate layer(s) from start vertex along baseDir.
        // If none are found (no metadata yet), we run without layer restriction.
        let candidateLayers: [UUID]? = {
            guard let ep = context.edgePolicy else { return nil }
            var s: Set<UUID> = []
            for eid in state.adjacency[startV.id] ?? [] {
                guard let e = state.edges[eid],
                      let n = state.vertices[(e.start == startV.id) ? e.end : e.start] else { continue }
                if isOnLine(a: startV.point, dir: baseDir, p: n.point, tol: tol),
                   let lid = ep.layerId(of: e) {
                    s.insert(lid)
                }
            }
            return s.isEmpty ? nil : Array(s)
        }()

        // Projection helpers for ordering/interval math
        let a = startV.point
        let dir = baseDir
        let denom = max(dir.dx * dir.dx + dir.dy * dir.dy, tol * tol)
        func t(_ p: CGPoint) -> CGFloat {
            ((p.x - a.x) * dir.dx + (p.y - a.y) * dir.dy) / denom
        }

        // Inner worker that collapses a single run restricted to `layer` (nil => no restriction).
        func collapseForLayer(_ layer: UUID?) {
            // 1) Collect run via DFS, restricted by collinearity and (optional) layer
            var run: [GraphVertex] = []
            var stack: [UUID] = [startV.id]
            var seen: Set<UUID> = [startV.id]

            while let vid = stack.popLast() {
                guard let v = state.vertices[vid] else { continue }
                run.append(v)

                for eid in state.adjacency[vid] ?? [] {
                    guard let e = state.edges[eid],
                          let n = state.vertices[(e.start == vid) ? e.end : e.start] else { continue }

                    // Layer gate
                    if let layer = layer {
                        guard let lid = context.edgePolicy?.layerId(of: e), lid == layer else { continue }
                    }
                    // Collinearity gate
                    guard isOnLine(a: startV.point, dir: baseDir, p: n.point, tol: tol) else { continue }

                    if !seen.contains(n.id) {
                        seen.insert(n.id)
                        stack.append(n.id)
                    }
                }
            }
            if run.count < 3 { return }

            // 2) Sort run along the line by projection
            run.sort { t($0.point) < t($1.point) }

            // 3) Collect edges that lie on this run (and on this layer if restricted), with their t-span
            let runIDs = Set(run.map { $0.id })
            struct SpanEdge { let edge: GraphEdge; let tMin: CGFloat; let tMax: CGFloat }
            var edgesOnRun: [SpanEdge] = []
            for e in state.edges.values {
                guard runIDs.contains(e.start), runIDs.contains(e.end),
                      let p1 = state.vertices[e.start]?.point,
                      let p2 = state.vertices[e.end]?.point,
                      isOnLine(a: a, dir: dir, p: p1, tol: tol),
                      isOnLine(a: a, dir: dir, p: p2, tol: tol) else { continue }
                if let layer = layer {
                    guard let lid = context.edgePolicy?.layerId(of: e), lid == layer else { continue }
                }
                let t1 = t(p1), t2 = t(p2)
                edgesOnRun.append(.init(edge: e, tMin: min(t1, t2), tMax: max(t1, t2)))
            }
            if edgesOnRun.isEmpty { return }

            // 4) Decide which vertices to keep (protected, junction/corner, or seam)
            var keep: Set<UUID> = []
            for v in run {
                if context.policy?.isProtected(v, state: state) ?? false {
                    keep.insert(v.id); continue
                }

                // Degree/junction test: only count edges on this layer (if restricted)
                let incidentEdgesAll = (state.adjacency[v.id] ?? []).compactMap { state.edges[$0] }
                let incidentEdges = incidentEdgesAll.filter { e in
                    if let layer = layer {
                        guard let lid = context.edgePolicy?.layerId(of: e) else { return false }
                        return lid == layer
                    }
                    return true
                }
                let deg = incidentEdges.count
                let collinearDeg = incidentEdges.reduce(0) { acc, e in
                    let nid = (e.start == v.id) ? e.end : e.start
                    guard let n = state.vertices[nid] else { return acc }
                    return acc + (isOnLine(a: v.point, dir: dir, p: n.point, tol: tol) ? 1 : 0)
                }
                if deg > collinearDeg {
                    keep.insert(v.id); continue
                }

                // Seam detection: only pass edges from the run (already layer-filtered)
                let vT = t(v.point)
                let incidentRunEdges = edgesOnRun.filter { se in
                    abs(se.tMin - vT) <= 10 * tol || abs(se.tMax - vT) <= 10 * tol
                }.map { $0.edge }

                if context.edgePolicy?.shouldPreserveVertex(v, connecting: incidentRunEdges) ?? false {
                    keep.insert(v.id); continue
                }
            }

            // Always keep the ends
            if let first = run.first { keep.insert(first.id) }
            if let last  = run.last  { keep.insert(last.id) }
            if keep.count >= run.count { return }

            // 5) Remove all run edges, and drop non-kept vertices only if they aren't used elsewhere
            let edgesToDelete = Set(edgesOnRun.map { $0.edge })
            for e in edgesToDelete { state.removeEdge(e.id) }

            let runConnectionEdgeIDs = Set(edgesOnRun.map { $0.edge.id })
            for v in run where !keep.contains(v.id) {
                // Do not delete the vertex if it still has other edges (e.g., another layer)
                let remaining = (state.adjacency[v.id] ?? []).subtracting(runConnectionEdgeIDs)
                if remaining.isEmpty {
                    state.removeVertex(v.id)
                }
            }

            // 6) Rebuild chain between consecutive kept vertices and propagate metadata from contributing spans
            let keptVerts = run.filter { keep.contains($0.id) }
            guard keptVerts.count >= 2 else { return }

            let keptT = keptVerts.map { t($0.point) }
            for i in 0..<(keptVerts.count - 1) {
                let vA = keptVerts[i], vB = keptVerts[i + 1]
                let tA = keptT[i],   tB = keptT[i + 1]
                let lo = min(tA, tB) - 10 * tol
                let hi = max(tA, tB) + 10 * tol

                if let newEdge = state.addEdge(from: vA.id, to: vB.id) {
                    // Contributing edges fully inside the interval
                    let contributing = edgesOnRun
                        .filter { $0.tMin >= lo && $0.tMax <= hi }
                        .map { $0.edge }

                    // Fallback: any overlap with the interval
                    let contributingFallback = contributing.isEmpty
                        ? edgesOnRun.filter { $0.tMax >= lo && $0.tMin <= hi }.map { $0.edge }
                        : contributing

                    context.edgePolicy?.propagateMetadata(from: contributingFallback, to: newEdge)
                }
            }
        }

        // Run per layer if we have layer info; otherwise, run once without restriction.
        if let layers = candidateLayers, !layers.isEmpty {
            // Process each layer independently to avoid cross-layer interaction.
            for layer in layers {
                collapseForLayer(layer)
            }
        } else {
            collapseForLayer(nil)
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
