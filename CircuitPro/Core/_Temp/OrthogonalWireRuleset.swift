//
//  OrthogonalWireRuleset.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct OrthogonalWireRuleset: GraphRuleset {
    func resolve(state: GraphState, context: ResolutionContext) -> GraphState {
        var s = state

        // 1) Merge coincident vertices around the epicenter
        let merged = mergeCoincidentVertices(in: context.epicenter, state: &s)

        // 2) Split edges that have intermediate vertices lying on them
        splitEdgesWithIntermediateVertices(state: &s)

        // 3) Cleanup collinear runs around epicenter and merged vertices
        var affected = context.epicenter
        affected.formUnion(merged)
        for id in affected {
            if s.vertices[id] != nil { cleanupCollinear(at: id, state: &s) }
        }

        // 4) Remove orphan free vertices
        for id in affected {
            if let v = s.vertices[id], (s.adjacency[id]?.isEmpty ?? true) {
                if case .free = v.ownership { s.removeVertex(id) }
            }
        }

        // 5) Unify net IDs across connected components that have become connected
        unifyNetsAround(affected, state: &s)

        return s
    }

    private func mergeCoincidentVertices(in scope: Set<UUID>, state: inout GraphState, tol: CGFloat = 1e-6) -> Set<UUID> {
        var toProcess = scope.compactMap { state.vertices[$0] }
        var processed: Set<UUID> = []
        var modified: Set<UUID> = []
        while let v = toProcess.popLast() {
            if processed.contains(v.id) { continue }
            let group = state.vertices.values.filter { hypot(v.point.x - $0.point.x, v.point.y - $0.point.y) < tol }
            if group.count > 1 {
                let survivor = group.first(where: { if case .pin = $0.ownership { return true } else { return false } }) ?? group.first!
                processed.insert(survivor.id)
                modified.insert(survivor.id)
                for victim in group where victim.id != survivor.id {
                    rewireEdges(from: victim.id, to: survivor.id, state: &state)
                    state.removeVertex(victim.id)
                    processed.insert(victim.id)
                }
            } else {
                processed.insert(v.id)
            }
        }
        return modified
    }

    private func rewireEdges(from oldID: UUID, to newID: UUID, state: inout GraphState) {
        if let edges = state.adjacency[oldID] {
            for eid in edges {
                guard let e = state.edges[eid] else { continue }
                let other = (e.start == oldID) ? e.end : e.start
                if other == newID { continue }
                _ = state.addEdge(from: newID, to: other)
            }
        }
    }

    private func splitEdgesWithIntermediateVertices(state: inout GraphState) {
        var splits: [(edgeID: UUID, vertexID: UUID)] = []
        let edges = Array(state.edges.values)
        let verts = Array(state.vertices.values)
        for e in edges {
            guard let p1 = state.vertices[e.start]?.point, let p2 = state.vertices[e.end]?.point else { continue }
            for v in verts where v.id != e.start && v.id != e.end {
                if state.isPoint(v.point, onSegmentBetween: p1, p2: p2) {
                    splits.append((e.id, v.id))
                }
            }
        }
        for s in splits {
            guard let e = state.edges[s.edgeID] else { continue }
            let a = e.start, b = e.end
            state.removeEdge(e.id)
            _ = state.addEdge(from: a, to: s.vertexID)
            _ = state.addEdge(from: s.vertexID, to: b)
        }
    }

    private func cleanupCollinear(at vertexID: UUID, state: inout GraphState) {
        guard let center = state.vertices[vertexID] else { return }
        guard case .free = center.ownership else { return }
        processRun(start: center, horizontal: true, state: &state)
        if state.vertices[vertexID] != nil {
            processRun(start: center, horizontal: false, state: &state)
        }
    }

    private func processRun(start: WireVertex, horizontal: Bool, state: inout GraphState) {
        var run: [WireVertex] = []
        var stack: [WireVertex] = [start]
        var seen: Set<UUID> = [start.id]

        func collinearNeighbors(of v: WireVertex) -> [WireVertex] {
            guard let eids = state.adjacency[v.id] else { return [] }
            var result: [WireVertex] = []
            for eid in eids {
                guard let e = state.edges[eid] else { continue }
                let nid = (e.start == v.id) ? e.end : e.start
                guard let n = state.vertices[nid] else { continue }
                if horizontal {
                    if abs(n.point.y - v.point.y) < 1e-6 { result.append(n) }
                } else {
                    if abs(n.point.x - v.point.x) < 1e-6 { result.append(n) }
                }
            }
            return result
        }

        while let v = stack.popLast() {
            run.append(v)
            for n in collinearNeighbors(of: v) where !seen.contains(n.id) {
                seen.insert(n.id)
                stack.append(n)
            }
        }
        if run.count < 3 { return }

        var kept: Set<UUID> = []
        for v in run {
            if case .pin = v.ownership { kept.insert(v.id); continue }
            let degree = state.adjacency[v.id]?.count ?? 0
            let collinearCount: Int = {
                var c = 0
                for n in collinearNeighbors(of: v) { c += 1 }
                return c
            }()
            if degree > collinearCount { kept.insert(v.id) }
        }

        if horizontal { run.sort { $0.point.x < $1.point.x } }
        else { run.sort { $0.point.y < $1.point.y } }
        if let first = run.first { kept.insert(first.id) }
        if let last = run.last { kept.insert(last.id) }
        if kept.count >= run.count { return }

        let runIDs = Set(run.map { $0.id })
        for v in run {
            if let eids = state.adjacency[v.id] {
                for eid in Array(eids) {
                    if let e = state.edges[eid] {
                        let other = (e.start == v.id) ? e.end : e.start
                        if runIDs.contains(other) { state.removeEdge(eid) }
                    }
                }
            }
        }
        for v in run where !kept.contains(v.id) { state.removeVertex(v.id) }

        let keptVerts = run.filter { kept.contains($0.id) }
        if keptVerts.count < 2 { return }
        for i in 0..<(keptVerts.count - 1) {
            _ = state.addEdge(from: keptVerts[i].id, to: keptVerts[i+1].id)
        }
    }

    private func unifyNetsAround(_ seeds: Set<UUID>, state: inout GraphState) {
        // Simple implementation: for each seed, flood, pick the first non-nil netID or create a new one, assign to all.
        var visited: Set<UUID> = []
        for seed in seeds {
            guard !visited.contains(seed) else { continue }
            let comp = bfs(from: seed, state: state)
            visited.formUnion(comp.vertices)
            guard !comp.edges.isEmpty else {
                for v in comp.vertices { state.vertices[v]?.netID = nil }
                continue
            }
            let existing = comp.vertices.compactMap { state.vertices[$0]?.netID }.first
            let finalID = existing ?? UUID()
            for v in comp.vertices { state.vertices[v]?.netID = finalID }
        }
    }

    private func bfs(from start: UUID, state: GraphState) -> (vertices: Set<UUID>, edges: Set<UUID>) {
        guard state.vertices[start] != nil else { return ([], []) }
        var vset: Set<UUID> = [start]
        var eset: Set<UUID> = []
        var q = [start]
        while let cur = q.popLast() {
            for eid in state.adjacency[cur] ?? [] {
                if eset.contains(eid) { continue }
                eset.insert(eid)
                guard let e = state.edges[eid] else { continue }
                let other = (e.start == cur) ? e.end : e.start
                if !vset.contains(other) {
                    vset.insert(other)
                    q.append(other)
                }
            }
        }
        return (vset, eset)
    }
}
