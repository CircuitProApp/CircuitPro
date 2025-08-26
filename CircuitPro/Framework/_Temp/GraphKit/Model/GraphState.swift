//
//  GraphState.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import SwiftUI

/// A pure, value-type snapshot of the graph's topology, geometry, and semantic data.
/// This struct has no behavior; it is simply the "source of truth" at a moment in time.
struct GraphState {
    // --- Topological & Geometric State ---
    var vertices: [GraphVertex.ID: GraphVertex]
    var edges: [GraphEdge.ID: GraphEdge]
    var adjacency: [GraphVertex.ID: Set<GraphEdge.ID>]

    /// Creates an empty graph state.
    static var empty: GraphState {
        GraphState(vertices: [:], edges: [:], adjacency: [:])
    }
}

extension GraphState {
    @discardableResult
    mutating func addVertex(at point: CGPoint, groupID: UUID? = nil) -> GraphVertex {
        let v = GraphVertex(id: UUID(), point: point, groupID: groupID)
        vertices[v.id] = v
        adjacency[v.id] = []
        return v
    }

    @discardableResult
    mutating func addEdge(from a: UUID, to b: UUID) -> GraphEdge? {
        guard vertices[a] != nil, vertices[b] != nil, a != b else { return nil }
        let already = adjacency[a]?.contains(where: { id in
            guard let e = edges[id] else { return false }
            return (e.start == a && e.end == b) || (e.start == b && e.end == a)
        }) ?? false
        if already { return nil }
        let e = GraphEdge(id: UUID(), start: a, end: b)
        edges[e.id] = e
        adjacency[a, default: []].insert(e.id)
        adjacency[b, default: []].insert(e.id)
        return e
    }

    mutating func removeEdge(_ id: UUID) {
        guard let e = edges.removeValue(forKey: id) else { return }
        adjacency[e.start]?.remove(id)
        adjacency[e.end]?.remove(id)
    }

    mutating func removeVertex(_ id: UUID) {
        if let edgeIDs = adjacency[id] {
            for eid in edgeIDs { removeEdge(eid) }
        }
        adjacency.removeValue(forKey: id)
        vertices.removeValue(forKey: id)
    }

    func findVertex(at point: CGPoint, tol: CGFloat) -> GraphVertex? {
        vertices.values.first { abs($0.point.x - point.x) < tol && abs($0.point.y - point.y) < tol }
    }

    func findEdge(at point: CGPoint, tol: CGFloat) -> GraphEdge? {
        for e in edges.values {
            guard let p1 = vertices[e.start]?.point, let p2 = vertices[e.end]?.point else { continue }
            if isPoint(point, onSegmentBetween: p1, p2: p2, tol: tol) { return e }
        }
        return nil
    }

    func isPoint(_ p: CGPoint, onSegmentBetween a: CGPoint, p2 b: CGPoint, tol: CGFloat) -> Bool {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx*dx + dy*dy
        if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) <= tol }
        // Perpendicular distance from P to line AB
        let cross = (p.x - a.x) * dy - (p.y - a.y) * dx
        if abs(cross) > tol * sqrt(len2) { return false }
        // Within segment extents (dot product parameterization)
        let dot = (p.x - a.x) * dx + (p.y - a.y) * dy
        if dot < -tol || dot > len2 + tol { return false }
        return true
    }

    @discardableResult
    mutating func connectStraight(from a: GraphVertex, to b: GraphVertex, tol: CGFloat) -> Set<UUID> {
        var affected: Set<UUID> = [a.id, b.id]
        var onPath: [GraphVertex] = [a, b]
        let others = vertices.values.filter {
            $0.id != a.id && $0.id != b.id &&
            isPoint($0.point, onSegmentBetween: a.point, p2: b.point, tol: tol)
        }
        for v in others { affected.insert(v.id) }
        onPath.append(contentsOf: others)

        // Sort by param t along AB
        let dx = b.point.x - a.point.x, dy = b.point.y - a.point.y
        let len2 = max(dx*dx + dy*dy, tol*tol)
        onPath.sort { v1, v2 in
            let t1 = ((v1.point.x - a.point.x) * dx + (v1.point.y - a.point.y) * dy) / len2
            let t2 = ((v2.point.x - a.point.x) * dx + (v2.point.y - a.point.y) * dy) / len2
            return t1 < t2
        }
        for i in 0..<(onPath.count - 1) { _ = addEdge(from: onPath[i].id, to: onPath[i+1].id) }
        return affected
    }
}

extension GraphState {
    static func computeDelta(from old: GraphState, to new: GraphState, tol: CGFloat) -> GraphDelta {
        var d = GraphDelta()
        let oldVerts = old.vertices, newVerts = new.vertices
        let oldIDs = Set(oldVerts.keys), newIDs = Set(newVerts.keys)
        d.createdVertices = newIDs.subtracting(oldIDs)
        d.deletedVertices = oldIDs.subtracting(newIDs)

        for id in oldIDs.intersection(newIDs) {
            let o = oldVerts[id]!, n = newVerts[id]!
            if hypot(o.point.x - n.point.x, o.point.y - n.point.y) > tol {
                d.movedVertices[id] = (o.point, n.point)
            }
            if o.groupID != n.groupID { d.changedGroupIDs[id] = (o.groupID, n.groupID) }
        }

        let oldEdges = Set(old.edges.keys), newEdges = Set(new.edges.keys)
        d.createdEdges = newEdges.subtracting(oldEdges)
        d.deletedEdges = oldEdges.subtracting(newEdges)
        return d
    }
}

extension GraphState {
    func neighbors(of id: UUID) -> [UUID] {
        guard let eids = adjacency[id] else { return [] }
        var out: [UUID] = []
        for eid in eids {
            guard let e = edges[eid] else { continue }
            out.append(e.start == id ? e.end : e.start)
        }
        return out
    }

    func component(from start: UUID) -> (vertices: Set<UUID>, edges: Set<UUID>) {
        guard vertices[start] != nil else { return ([], []) }
        var vset: Set<UUID> = [start]
        var eset: Set<UUID> = []
        var stack: [UUID] = [start]
        while let cur = stack.popLast() {
            for eid in adjacency[cur] ?? [] where !eset.contains(eid) {
                eset.insert(eid)
                guard let e = edges[eid] else { continue }
                let other = (e.start == cur) ? e.end : e.start
                if !vset.contains(other) {
                    vset.insert(other)
                    stack.append(other)
                }
            }
        }
        return (vset, eset)
    }
}

extension GraphState {
    @discardableResult
    mutating func splitEdge(_ edgeID: UUID, at point: CGPoint) -> GraphVertex.ID? {
        guard let e = edges[edgeID] else { return nil }
        let startID = e.start, endID = e.end
        let originalGroupID = vertices[startID]?.groupID
        removeEdge(edgeID)
        let newV = addVertex(at: point, groupID: originalGroupID)
        _ = addEdge(from: startID, to: newV.id)
        _ = addEdge(from: newV.id, to: endID)
        return newV.id
    }
}
