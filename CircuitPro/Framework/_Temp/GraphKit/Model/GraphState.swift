//
//  GraphState.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import SwiftUI
/// A pure, value-type snapshot of the graph's topology, geometry, and semantic data.
/// This struct has no behavior; it is simply the "source of truth" at a moment in time.
public struct GraphState {
    // --- Topological & Geometric State ---
    // CORRECTED: Properties are now 'var' to allow mutation on a *copy* of the state.
    // The struct itself remains a value type, ensuring state changes are explicit.
    var vertices: [WireVertex.ID: WireVertex]
    var edges: [WireEdge.ID: WireEdge]
    var adjacency: [WireVertex.ID: Set<WireEdge.ID>]

    // --- Semantic State ---
    var netNames: [UUID: String]

    /// Creates an empty graph state.
    static var empty: GraphState {
        GraphState(vertices: [:], edges: [:], adjacency: [:], netNames: [:])
    }
}

public extension GraphState {
    @discardableResult
    internal mutating func addVertex(at point: CGPoint, ownership: VertexOwnership, netID: UUID? = nil) -> WireVertex {
        let v = WireVertex(id: UUID(), point: point, ownership: ownership, netID: netID)
        vertices[v.id] = v
        adjacency[v.id] = []
        return v
    }

    @discardableResult
    internal mutating func addEdge(from a: UUID, to b: UUID) -> WireEdge? {
        guard vertices[a] != nil, vertices[b] != nil else { return nil }
        let already = adjacency[a]?.contains(where: { id in
            guard let e = edges[id] else { return false }
            return (e.start == a && e.end == b) || (e.start == b && e.end == a)
        }) ?? false
        if already { return nil }
        let e = WireEdge(id: UUID(), start: a, end: b)
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

    internal func findVertex(at point: CGPoint, tol: CGFloat) -> WireVertex? {
        vertices.values.first { abs($0.point.x - point.x) < tol && abs($0.point.y - point.y) < tol }
    }

    internal func findEdge(at point: CGPoint, tol: CGFloat) -> WireEdge? {
        for e in edges.values {
            guard let p1 = vertices[e.start]?.point, let p2 = vertices[e.end]?.point else { continue }
            if isPoint(point, onSegmentBetween: p1, p2: p2, tol: tol) { return e }
        }
        return nil
    }

    func isPoint(_ p: CGPoint, onSegmentBetween p1: CGPoint, p2: CGPoint, tol: CGFloat) -> Bool {
        let minX = min(p1.x, p2.x) - tol, maxX = max(p1.x, p2.x) + tol
        let minY = min(p1.y, p2.y) - tol, maxY = max(p1.y, p2.y) + tol
        guard p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY else { return false }
        if abs(p1.y - p2.y) < tol { return abs(p.y - p1.y) < tol }
        if abs(p1.x - p2.x) < tol { return abs(p.x - p1.x) < tol }
        return false
    }

    @discardableResult
    internal mutating func connectStraight(from a: WireVertex, to b: WireVertex, tol: CGFloat) -> Set<UUID> {
        var affected: Set<UUID> = [a.id, b.id]
        var onPath: [WireVertex] = [a, b]
        let others = vertices.values.filter {
            $0.id != a.id && $0.id != b.id &&
            isPoint($0.point, onSegmentBetween: a.point, p2: b.point, tol: tol)
        }
        for v in others { affected.insert(v.id) }
        onPath.append(contentsOf: others)

        if abs(a.point.x - b.point.x) < tol {
            onPath.sort { $0.point.y < $1.point.y } // vertical
        } else {
            onPath.sort { $0.point.x < $1.point.x } // horizontal
        }
        for i in 0..<(onPath.count - 1) {
            _ = addEdge(from: onPath[i].id, to: onPath[i+1].id)
        }
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
            if o.ownership != n.ownership { d.changedOwnership[id] = (o.ownership, n.ownership) }
            if o.netID != n.netID { d.changedNetIDs[id] = (o.netID, n.netID) }
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
    mutating func splitEdge(_ edgeID: UUID, at point: CGPoint, ownership: VertexOwnership) -> WireVertex.ID? {
        guard let e = edges[edgeID] else { return nil }
        let startID = e.start, endID = e.end
        let originalNetID = vertices[startID]?.netID
        removeEdge(edgeID)
        let newV = addVertex(at: point, ownership: ownership, netID: originalNetID)
        _ = addEdge(from: startID, to: newV.id)
        _ = addEdge(from: newV.id, to: endID)
        return newV.id
    }
}
