//
//  WireGraph.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/17/25.
//

import Foundation
import SwiftUI

@Observable
final class WireGraph {
    // MARK: - Engine and State (stable engine instance)
    public let engine: GraphEngine

    // Read-only convenience accessors to current state
    public var vertices: [GraphVertex.ID: GraphVertex] { engine.currentState.vertices }
    public var edges: [GraphEdge.ID: GraphEdge] { engine.currentState.edges }
    public var adjacency: [GraphVertex.ID: Set<GraphEdge.ID>] { engine.currentState.adjacency }

    // MARK: - UI-only drag state (will be moved to transactions later)
    private struct DragState {
        let originalVertexPositions: [UUID: CGPoint]
        let selectedEdges: [GraphEdge]
        let verticesToMove: Set<UUID>
        var newVertices: Set<UUID> = []
    }
    private var dragState: DragState?

    // Called whenever engine publishes a change
    var onModelDidChange: (() -> Void)?

    // MARK: - Init
    init() {
        let grid = ManhattanGrid(step: 1) // pick your grid spacing
        engine = GraphEngine(initialState: .empty, ruleset: OrthogonalWireRuleset(), grid: grid)
        engine.onChange = { [weak self] _, _ in
            self?.onModelDidChange?()
        }
    }
    // MARK: - Net Definition (unchanged)
    struct Net: Identifiable, Hashable, Equatable {
        let id: UUID
        var name: String
        let vertexCount: Int
        let edgeCount: Int
    }

    enum WireConnectionStrategy {
        case horizontalThenVertical
        case verticalThenHorizontal
    }

    // MARK: - Persistence

    // Build a new GraphState from wires and replace engine state in one go (no incremental ruleset resolution needed here)
    public func build(from wires: [Wire]) {
        if wires.isEmpty {
            engine.replaceState(.empty)
            return
        }

        var newVertices: [GraphVertex.ID: GraphVertex] = [:]
        var newEdges: [GraphEdge.ID: GraphEdge] = [:]
        var newAdjacency: [GraphVertex.ID: Set<GraphEdge.ID>] = [:]
        var newNetNames: [UUID: String] = [:]
        var attachmentMap: [AttachmentPoint: GraphVertex.ID] = [:]

        func addVertex(at point: CGPoint, ownership: VertexOwnership) -> GraphVertex {
            let v = GraphVertex(id: UUID(), point: point, ownership: ownership, groupID: nil)
            newVertices[v.id] = v
            newAdjacency[v.id] = []
            return v
        }

        func addEdge(from a: GraphVertex.ID, to b: GraphVertex.ID) {
            let e = GraphEdge(id: UUID(), start: a, end: b)
            newEdges[e.id] = e
            newAdjacency[a, default: []].insert(e.id)
            newAdjacency[b, default: []].insert(e.id)
        }

        func getVertexID(for point: AttachmentPoint, netID: UUID) -> GraphVertex.ID {
            if let existingID = attachmentMap[point] { return existingID }
            let v: GraphVertex
            switch point {
            case .free(let pt):
                v = addVertex(at: pt, ownership: .free)
            case .pin(let owner, let pin):
                // Create at zero; syncPins will position later
                v = addVertex(at: .zero, ownership: .pin(ownerID: owner, pinID: pin))
            }
            newVertices[v.id]?.groupID = netID
            attachmentMap[point] = v.id
            return v.id
        }

        for wire in wires {
            for seg in wire.segments {
                let a = getVertexID(for: seg.start, netID: wire.id)
                let b = getVertexID(for: seg.end, netID: wire.id)
                if a != b { addEdge(from: a, to: b) }
            }
        }

        let newState = GraphState(vertices: newVertices, edges: newEdges, adjacency: newAdjacency, groupNames: newNetNames)
        engine.replaceState(newState)
    }

    public func toWires() -> [Wire] {
        var wires: [Wire] = []
        var processed = Set<UUID>()
        let s = engine.currentState

        for vID in s.vertices.keys where !processed.contains(vID) {
            let (compV, compE) = net(startingFrom: vID, in: s)
            processed.formUnion(compV)
            guard !compE.isEmpty, let netID = s.vertices[vID]?.groupID else { continue }

            let segments: [WireSegment] = compE.compactMap { eid in
                guard let e = s.edges[eid],
                      let a = s.vertices[e.start],
                      let b = s.vertices[e.end],
                      let ap = attachmentPoint(for: a),
                      let bp = attachmentPoint(for: b) else { return nil }
                return WireSegment(start: ap, end: bp)
            }
            if !segments.isEmpty {
                wires.append(Wire(id: netID, segments: segments))
            }
        }
        return wires
    }

    private func attachmentPoint(for v: GraphVertex) -> AttachmentPoint? {
        switch v.ownership {
        case .free, .detachedPin: return .free(point: v.point)
        case .pin(let ownerID, let pinID): return .pin(componentInstanceID: ownerID, pinID: pinID)
        }
    }

    // MARK: - Public API (transactions-first)

    public func setName(_ name: String, for netID: UUID) {
        var tx = SetGroupNameTransaction(netID: netID, name: name)
        _ = engine.execute(transaction: &tx)
    }

    public func releasePins(for ownerID: UUID) {
        var tx = ReleasePinsTransaction(ownerID: ownerID)
        _ = engine.execute(transaction: &tx)
    }

    func getOrCreateVertex(at point: CGPoint) -> GraphVertex.ID {
        var tx = GetOrCreateVertexTransaction(point: point)
        _ = engine.execute(transaction: &tx)
        precondition(tx.createdID != nil, "GetOrCreateVertexTransaction must yield an ID")
        return tx.createdID!
    }

    func getOrCreatePinVertex(at point: CGPoint, ownerID: UUID, pinID: UUID) -> GraphVertex.ID {
        var tx = GetOrCreatePinVertexTransaction(point: point, ownerID: ownerID, pinID: pinID)
        _ = engine.execute(transaction: &tx)
        precondition(tx.vertexID != nil, "GetOrCreatePinVertexTransaction must yield an ID")
        return tx.vertexID!
    }

    func connect(from startID: UUID, to endID: UUID, preferring strategy: WireConnectionStrategy = .horizontalThenVertical) {
        let s: ConnectVerticesTransaction.Strategy = (strategy == .horizontalThenVertical) ? .hThenV : .vThenH
        var tx = ConnectVerticesTransaction(startID: startID, endID: endID, strategy: s)
        _ = engine.execute(transaction: &tx)
    }
    
    func connect(from startPoint: CGPoint, to endPoint: CGPoint, preferring strategy: WireConnectionStrategy = .horizontalThenVertical) {
        let s: ConnectVerticesTransaction.Strategy = (strategy == .horizontalThenVertical) ? .hThenV : .vThenH
        var tx = ConnectPointsTransaction(start: startPoint, end: endPoint, strategy: s)
        _ = engine.execute(transaction: &tx)
    }

    func delete(items: Set<UUID>) {
        var tx = DeleteItemsTransaction(items: items)
        _ = engine.execute(transaction: &tx)
    }

    // MARK: - Drag Lifecycle (Phase 1: keep here, no normalization during drag)

    public func beginDrag(selectedIDs: Set<UUID>) -> Bool {
        let s = engine.currentState

        // 1) Pins of selected symbols
        let symbolPinVertexIDs = s.vertices.values
            .filter { if case .pin(let ownerID, _) = $0.ownership { return selectedIDs.contains(ownerID) } else { return false } }
            .map { $0.id }

        // 2) Selected edges
        let selectedEdges = s.edges.values.filter { selectedIDs.contains($0.id) }

        // 3) Movable vertices from those edges, excluding pins
        let movableEdgeVertexIDs = selectedEdges
            .flatMap { [$0.start, $0.end] }
            .filter { vid in
                guard let v = s.vertices[vid] else { return false }
                if case .pin = v.ownership { return false }
                return true
            }

        let allMovable = Set(symbolPinVertexIDs).union(movableEdgeVertexIDs)
        guard !allMovable.isEmpty else {
            dragState = nil
            return false
        }

        dragState = DragState(
            originalVertexPositions: s.vertices.mapValues { $0.point },
            selectedEdges: selectedEdges,
            verticesToMove: allMovable
        )
        return true
    }

    // During drag we directly replace engine state (skip ruleset) so we don't normalize continuously.
    public func updateDrag(by delta: CGPoint) {
        guard var ds = dragState else { return }
        var s = engine.currentState

        // 1) Pre-process: detaching selected pins that are pulled off-axis
        for vertexID in ds.verticesToMove {
            guard let v = s.vertices[vertexID], case .pin = v.ownership else { continue }

            let isOffAxis = (s.adjacency[vertexID] ?? []).contains { edgeID in
                guard ds.selectedEdges.contains(where: { $0.id == edgeID }) else { return false }
                guard let e = s.edges[edgeID] else { return false }
                let otherEndID = (e.start == vertexID) ? e.end : e.start
                if ds.verticesToMove.contains(otherEndID) { return false }
                guard let orig = ds.originalVertexPositions[vertexID],
                      let otherOrig = ds.originalVertexPositions[otherEndID] else { return false }
                let wasHorizontal = abs(orig.y - otherOrig.y) < 1e-6
                return (wasHorizontal && abs(delta.y) > 1e-6) || (!wasHorizontal && abs(delta.x) > 1e-6)
            }

            if isOffAxis {
                let pinOwnership = v.ownership
                let pinPoint = v.point
                s.vertices[vertexID]?.ownership = .detachedPin
                let newStatic = s.addVertex(at: pinPoint, ownership: pinOwnership)
                ds.newVertices.insert(newStatic.id)
                _ = s.addEdge(from: vertexID, to: newStatic.id)
            }
        }
        self.dragState = ds

        // 2) Initial displaced positions for the moving set
        var newPositions: [UUID: CGPoint] = [:]
        for id in ds.verticesToMove {
            if let origin = ds.originalVertexPositions[id] {
                newPositions[id] = CGPoint(x: origin.x + delta.x, y: origin.y + delta.y)
            }
        }

        // 3) L-bend for detached pins
        for vertexID in ds.verticesToMove {
            if let v = s.vertices[vertexID], v.ownership == .detachedPin {
                guard let staticPinNeighbor = findNeighbor(of: vertexID, in: s, where: { nID, _ in
                          if case .pin = s.vertices[nID]?.ownership { return newPositions[nID] == nil } else { return false }
                      }),
                      let movingNeighbor = findNeighbor(of: vertexID, in: s, where: { nID, e in
                          return newPositions[nID] != nil && ds.selectedEdges.contains { $0.id == e.id }
                      }) else { continue }
                let origV = ds.originalVertexPositions[vertexID]!
                let origM = ds.originalVertexPositions[movingNeighbor.id]!
                let newM = newPositions[movingNeighbor.id]!
                let wasHorizontal = abs(origV.y - origM.y) < 1e-6
                newPositions[vertexID] = wasHorizontal
                    ? CGPoint(x: staticPinNeighbor.point.x, y: newM.y)
                    : CGPoint(x: newM.x, y: staticPinNeighbor.point.y)
            }
        }

        // 4) Propagate axis constraints via BFS from the moving set
        var queue = Array(ds.verticesToMove)
        var queued = ds.verticesToMove
        var head = 0

        while head < queue.count {
            let junctionID = queue[head]; head += 1
            guard let junctionNewPos = newPositions[junctionID],
                  let junctionOrigPos = ds.originalVertexPositions[junctionID] else { continue }

            for edgeID in s.adjacency[junctionID] ?? [] {
                guard let e = s.edges[edgeID] else { continue }
                let anchorID = (e.start == junctionID) ? e.end : e.start
                if ds.verticesToMove.contains(anchorID) { continue }

                guard let anchorOrigPos = ds.originalVertexPositions[anchorID] else { continue }
                var updatedAnchorPos = newPositions[anchorID] ?? anchorOrigPos
                let wasHorizontal = abs(anchorOrigPos.y - junctionOrigPos.y) < 1e-6

                if var anchorVertex = s.vertices[anchorID], case .pin(let owner, let pin) = anchorVertex.ownership {
                    let isOffAxisPull = (wasHorizontal && abs(junctionNewPos.y - anchorOrigPos.y) > 1e-6)
                        || (!wasHorizontal && abs(junctionNewPos.x - anchorOrigPos.x) > 1e-6)
                    if isOffAxisPull {
                        updatedAnchorPos = wasHorizontal
                            ? CGPoint(x: anchorOrigPos.x, y: junctionNewPos.y)
                            : CGPoint(x: junctionNewPos.x, y: anchorOrigPos.y)
                        if case .pin = anchorVertex.ownership {
                            anchorVertex.ownership = .detachedPin
                            s.vertices[anchorID] = anchorVertex
                            let newStaticPin = s.addVertex(at: anchorOrigPos, ownership: .pin(ownerID: owner, pinID: pin))
                            self.dragState?.newVertices.insert(newStaticPin.id)
                            _ = s.addEdge(from: anchorID, to: newStaticPin.id)
                        }
                    } else {
                        continue
                    }
                } else {
                    if wasHorizontal { updatedAnchorPos.y = junctionNewPos.y }
                    else { updatedAnchorPos.x = junctionNewPos.x }
                }

                if newPositions[anchorID] != updatedAnchorPos {
                    newPositions[anchorID] = updatedAnchorPos
                    if !queued.contains(anchorID) {
                        queue.append(anchorID)
                        queued.insert(anchorID)
                    }
                }
            }
        }

        // 5) Apply positions atomically (no normalization)
        for (id, pos) in newPositions {
            if s.vertices[id]?.point != pos {
                s.vertices[id]?.point = pos
            }
        }

        engine.replaceState(s) // push updated geometry without ruleset cleanup
    }

    public func endDrag() {
        guard let ds = dragState else { return }
        var s = engine.currentState

        // Convert temporary detached pins back to free vertices
        for (id, v) in s.vertices {
            if case .detachedPin = v.ownership {
                var vv = v
                vv.ownership = .free
                s.vertices[id] = vv
            }
        }

        // Normalize around the affected region via ruleset.
        // Fix: turn keys into a Set before union.
        let epicenter = Set(ds.originalVertexPositions.keys).union(ds.newVertices)
        var tx = LoadStateTransaction(newState: s, epicenter: epicenter)
        _ = engine.execute(transaction: &tx)

        self.dragState = nil
    }

    // MARK: - Discovery utilities

    // BFS for a connected component (used by toWires())
    private func net(startingFrom start: UUID, in state: GraphState) -> (vertices: Set<UUID>, edges: Set<UUID>) {
        guard state.vertices[start] != nil else { return ([], []) }
        var vset: Set<UUID> = [start]
        var eset: Set<UUID> = []
        var stack = [start]
        while let cur = stack.popLast() {
            for eid in state.adjacency[cur] ?? [] where !eset.contains(eid) {
                eset.insert(eid)
                guard let e = state.edges[eid] else { continue }
                let other = (e.start == cur) ? e.end : e.start
                if !vset.contains(other) {
                    vset.insert(other)
                    stack.append(other)
                }
            }
        }
        return (vset, eset)
    }

    // Neighbor search helper for drag propagation
    private func findNeighbor(of vertexID: UUID, in state: GraphState, where predicate: (UUID, GraphEdge) -> Bool) -> GraphVertex? {
        guard let edgeIDs = state.adjacency[vertexID] else { return nil }
        for eid in edgeIDs {
            guard let e = state.edges[eid] else { continue }
            let nid = (e.start == vertexID) ? e.end : e.start
            if predicate(nid, e) { return state.vertices[nid] }
        }
        return nil
    }

    // Convenience: find a vertex by pin ownership in current state
    func findVertex(ownedBy ownerID: UUID, pinID: UUID) -> GraphVertex.ID? {
        for v in engine.currentState.vertices.values {
            if case .pin(let o, let p) = v.ownership, o == ownerID, p == pinID { return v.id }
        }
        return nil
    }

    // MARK: - Pin sync (document load -> actual positions)

    func syncPins(for symbolInstance: SymbolInstance, of symbolDefinition: SymbolDefinition, ownerID: UUID) {
        for pinDef in symbolDefinition.pins {
            let rotated = pinDef.position.applying(CGAffineTransform(rotationAngle: symbolInstance.rotation))
            let absPos = CGPoint(x: symbolInstance.position.x + rotated.x, y: symbolInstance.position.y + rotated.y)

            if let existingID = findVertex(ownedBy: ownerID, pinID: pinDef.id) {
                var tx = MoveVertexTransaction(id: existingID, newPoint: absPos)
                _ = engine.execute(transaction: &tx)
            } else {
                var tx = GetOrCreatePinVertexTransaction(point: absPos, ownerID: ownerID, pinID: pinDef.id)
                _ = engine.execute(transaction: &tx)
            }
        }
    }
}
