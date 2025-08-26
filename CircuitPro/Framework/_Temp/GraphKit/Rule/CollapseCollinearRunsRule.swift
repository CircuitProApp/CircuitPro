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

        // Optionally scope to neighborhood AABB to keep this local
        let scopedSeeds: [UUID] = seeds.compactMap { id in
            guard let p = state.vertices[id]?.point else { return nil }
            return context.neighborhood.contains(p) ? id : nil
        }

        for id in scopedSeeds {
            guard let center = state.vertices[id] else { continue }
            guard case .free = center.ownership else { continue }

            processRun(start: id, horizontal: true, tol: tol, state: &state)
            if state.vertices[id] != nil {
                processRun(start: id, horizontal: false, tol: tol, state: &state)
            }
        }
    }

    private func processRun(start: UUID, horizontal: Bool, tol: CGFloat, state: inout GraphState) {
        guard let startV = state.vertices[start] else { return }

        // Collect all vertices reachable via collinear edges in this orientation
        var run: [GraphVertex] = []
        var stack: [GraphVertex] = [startV]
        var seen: Set<UUID> = [startV.id]

        while let v = stack.popLast() {
            run.append(v)
            for n in collinearNeighbors(of: v, horizontal: horizontal, tol: tol, state: state) where !seen.contains(n.id) {
                seen.insert(n.id)
                stack.append(n)
            }
        }
        if run.count < 3 { return }

        // Decide which vertices to keep
        var keep: Set<UUID> = []
        for v in run {
            if case .pin = v.ownership { keep.insert(v.id); continue }
            let degree = state.adjacency[v.id]?.count ?? 0
            let collinearDegree = collinearNeighbors(of: v, horizontal: horizontal, tol: tol, state: state).count
            if degree > collinearDegree { keep.insert(v.id) } // branching or corner
        }

        // Always keep endpoints of the run
        if horizontal { run.sort { $0.point.x < $1.point.x } }
        else { run.sort { $0.point.y < $1.point.y } }
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

    private func collinearNeighbors(of v: GraphVertex, horizontal: Bool, tol: CGFloat, state: GraphState) -> [GraphVertex] {
        guard let eids = state.adjacency[v.id] else { return [] }
        var out: [GraphVertex] = []
        for eid in eids {
            guard let e = state.edges[eid] else { continue }
            let nid = (e.start == v.id) ? e.end : e.start
            guard let n = state.vertices[nid] else { continue }
            if horizontal {
                if abs(n.point.y - v.point.y) < tol { out.append(n) }
            } else {
                if abs(n.point.x - v.point.x) < tol { out.append(n) }
            }
        }
        return out
    }
}
