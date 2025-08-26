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

    // Domain metadata: schematic ownership (pins, detached pins, free)
    private(set) var ownership: [UUID: VertexOwnership] = [:]

    // MARK: - UI-only drag state (no normalization during drag)
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
        // Build policy without capturing self
        let lookupBox = OwnershipLookupBox()
        let policy = WireVertexPolicy(box: lookupBox)

        // Create engine as a stored property
        let grid = ManhattanGrid(step: 1)
        self.engine = GraphEngine(
            initialState: .empty,
            ruleset: OrthogonalWireRuleset(),
            grid: grid,
            policy: policy
        )

        // Now that self is fully initialized, connect the lookup
        lookupBox.lookup = { [weak self] vid in self?.ownership[vid] }

        // Observe engine changes to keep ownership map in sync
        engine.onChange = { [weak self] delta, _ in
            guard let self = self else { return }
            for id in delta.deletedVertices { self.ownership.removeValue(forKey: id) }
            for id in delta.createdVertices where self.ownership[id] == nil {
                self.ownership[id] = .free
            }
            self.onModelDidChange?()
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

    // Build a new GraphState from wires and replace engine state in one go
    public func build(from wires: [Wire]) {
        if wires.isEmpty {
            engine.replaceState(.empty)
            ownership = [:]
            return
        }

        var newVertices: [GraphVertex.ID: GraphVertex] = [:]
        var newEdges: [GraphEdge.ID: GraphEdge] = [:]
        var newAdjacency: [GraphVertex.ID: Set<GraphEdge.ID>] = [:]
        var newGroupNames: [UUID: String] = [:]
        var attachmentMap: [AttachmentPoint: GraphVertex.ID] = [:]
        var newOwnership: [UUID: VertexOwnership] = [:]

        func addVertex(at point: CGPoint, own: VertexOwnership) -> GraphVertex {
            let v = GraphVertex(id: UUID(), point: point, groupID: nil)
            newVertices[v.id] = v
            newAdjacency[v.id] = []
            newOwnership[v.id] = own
            return v
        }

        func addEdge(from a: GraphVertex.ID, to b: GraphVertex.ID) {
            let e = GraphEdge(id: UUID(), start: a, end: b)
            newEdges[e.id] = e
            newAdjacency[a, default: []].insert(e.id)
            newAdjacency[b, default: []].insert(e.id)
        }

        func getVertexID(for point: AttachmentPoint, groupID: UUID) -> GraphVertex.ID {
            if let existingID = attachmentMap[point] { return existingID }
            let v: GraphVertex
            switch point {
            case .free(let pt):
                v = addVertex(at: pt, own: .free)
            case .pin(let owner, let pin):
                // Create at zero; syncPins will position later
                v = addVertex(at: .zero, own: .pin(ownerID: owner, pinID: pin))
            }
            newVertices[v.id]?.groupID = groupID
            attachmentMap[point] = v.id
            return v.id
        }

        for wire in wires {
            for seg in wire.segments {
                let a = getVertexID(for: seg.start, groupID: wire.id)
                let b = getVertexID(for: seg.end, groupID: wire.id)
                if a != b { addEdge(from: a, to: b) }
            }
        }

        let newState = GraphState(vertices: newVertices, edges: newEdges, adjacency: newAdjacency, groupNames: newGroupNames)
        engine.replaceState(newState)
        // Overwrite ownership map with reconstructed values
        ownership = newOwnership
    }

    public func toWires() -> [Wire] {
        var wires: [Wire] = []
        var processed = Set<UUID>()
        let s = engine.currentState

        for vID in s.vertices.keys where !processed.contains(vID) {
            let (compV, compE) = net(startingFrom: vID, in: s)
            processed.formUnion(compV)
            guard !compE.isEmpty, let groupID = s.vertices[vID]?.groupID else { continue }

            let segments: [WireSegment] = compE.compactMap { eid in
                guard let e = s.edges[eid],
                      let a = s.vertices[e.start],
                      let b = s.vertices[e.end],
                      let ap = attachmentPoint(for: a),
                      let bp = attachmentPoint(for: b) else { return nil }
                return WireSegment(start: ap, end: bp)
            }
            if !segments.isEmpty {
                wires.append(Wire(id: groupID, segments: segments))
            }
        }
        return wires
    }

    private func attachmentPoint(for v: GraphVertex) -> AttachmentPoint? {
        switch ownership[v.id] ?? .free {
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
        // Domain-only change: update ownership map and trigger a localized resolve
        var epicenter: Set<UUID> = []
        for (vid, own) in ownership {
            if case .pin(let o, _) = own, o == ownerID {
                ownership[vid] = .free
                epicenter.insert(vid)
            }
        }
        if !epicenter.isEmpty {
            var tx = LoadStateTransaction(newState: engine.currentState, epicenter: epicenter)
            _ = engine.execute(transaction: &tx)
        }
    }

    func getOrCreateVertex(at point: CGPoint) -> GraphVertex.ID {
        var tx = GetOrCreateVertexTransaction(point: point)
        _ = engine.execute(transaction: &tx)
        precondition(tx.createdID != nil, "GetOrCreateVertexTransaction must yield an ID")
        return tx.createdID!
    }

    @discardableResult
    func getOrCreatePinVertex(at point: CGPoint, ownerID: UUID, pinID: UUID) -> GraphVertex.ID {
        var tx = GetOrCreateVertexTransaction(point: point)
        _ = engine.execute(transaction: &tx)
        precondition(tx.createdID != nil, "GetOrCreateVertexTransaction must yield an ID")
        let vid = tx.createdID!
        ownership[vid] = .pin(ownerID: ownerID, pinID: pinID)
        return vid
    }

    func connect(from startPoint: CGPoint,
                 to endPoint: CGPoint,
                 preferring strategy: WireConnectionStrategy = .horizontalThenVertical) {
        let s: ConnectVerticesTransaction.Strategy =
            (strategy == .horizontalThenVertical) ? .hThenV : .vThenH
        var tx = ConnectPointsTransaction(start: startPoint, end: endPoint, strategy: s)
        _ = engine.execute(transaction: &tx)
    }

    func connect(from startID: UUID,
                 to endID: UUID,
                 preferring strategy: WireConnectionStrategy = .horizontalThenVertical) {
        let s: ConnectVerticesTransaction.Strategy =
            (strategy == .horizontalThenVertical) ? .hThenV : .vThenH
        var tx = ConnectVerticesTransaction(startID: startID, endID: endID, strategy: s)
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
        let symbolPinVertexIDs = s.vertices.keys.filter { vid in
            if case .pin(let ownerID, _) = ownership[vid] { return selectedIDs.contains(ownerID) }
            return false
        }

        // 2) Selected edges
        let selectedEdges = s.edges.values.filter { selectedIDs.contains($0.id) }

        // 3) Movable vertices from those edges, excluding pins
        let movableEdgeVertexIDs = selectedEdges
            .flatMap { [$0.start, $0.end] }
            .filter { vid in
                if case .pin = ownership[vid] { return false }
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
        let tol = engine.grid.epsilon

        // 1) Pre-process: detaching selected pins that are pulled off-axis
        for vertexID in ds.verticesToMove {
            guard case .pin = ownership[vertexID] else { continue }

            let isOffAxis = (s.adjacency[vertexID] ?? []).contains { edgeID in
                guard ds.selectedEdges.contains(where: { $0.id == edgeID }) else { return false }
                guard let e = s.edges[edgeID] else { return false }
                let otherEndID = (e.start == vertexID) ? e.end : e.start
                if ds.verticesToMove.contains(otherEndID) { return false }
                guard let orig = ds.originalVertexPositions[vertexID],
                      let otherOrig = ds.originalVertexPositions[otherEndID] else { return false }
                let wasHorizontal = abs(orig.y - otherOrig.y) < tol
                return (wasHorizontal && abs(delta.y) > tol) || (!wasHorizontal && abs(delta.x) > tol)
            }

            if isOffAxis {
                let pinOwnership = ownership[vertexID] ?? .free
                let pinPoint = s.vertices[vertexID]?.point ?? .zero
                ownership[vertexID] = .detachedPin
                let newStatic = s.addVertex(at: pinPoint, groupID: s.vertices[vertexID]?.groupID)
                ds.newVertices.insert(newStatic.id)
                ownership[newStatic.id] = pinOwnership
                _ = s.addEdge(from: vertexID, to: newStatic.id)
            }
        }

        // 2) Initial displaced positions for the moving set
        var newPositions: [UUID: CGPoint] = [:]
        for id in ds.verticesToMove {
            if let origin = ds.originalVertexPositions[id] {
                newPositions[id] = CGPoint(x: origin.x + delta.x, y: origin.y + delta.y)
            }
        }

        // 3) L-bend for detached pins
        for vertexID in ds.verticesToMove {
            if ownership[vertexID] == .detachedPin {
                guard let staticPinNeighbor = findNeighbor(of: vertexID, in: s, where: { nID, _ in
                          if case .pin = self.ownership[nID] { return newPositions[nID] == nil } else { return false }
                      }),
                      let movingNeighbor = findNeighbor(of: vertexID, in: s, where: { nID, e in
                          return newPositions[nID] != nil && ds.selectedEdges.contains { $0.id == e.id }
                      }),
                      let origV = ds.originalVertexPositions[vertexID],
                      let origM = ds.originalVertexPositions[movingNeighbor.id],
                      let newM = newPositions[movingNeighbor.id] else { continue }
                let wasHorizontal = abs(origV.y - origM.y) < tol
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
                let wasHorizontal = abs(anchorOrigPos.y - junctionOrigPos.y) < tol

                if case .pin(let owner, let pin) = ownership[anchorID] {
                    let isOffAxisPull = (wasHorizontal && abs(junctionNewPos.y - anchorOrigPos.y) > tol)
                        || (!wasHorizontal && abs(junctionNewPos.x - anchorOrigPos.x) > tol)
                    if isOffAxisPull {
                        updatedAnchorPos = wasHorizontal
                            ? CGPoint(x: anchorOrigPos.x, y: junctionNewPos.y)
                            : CGPoint(x: junctionNewPos.x, y: anchorOrigPos.y)

                        ownership[anchorID] = .detachedPin
                        let newStaticPin = s.addVertex(at: anchorOrigPos, groupID: s.vertices[anchorID]?.groupID)
                        ds.newVertices.insert(newStaticPin.id)
                        ownership[newStaticPin.id] = .pin(ownerID: owner, pinID: pin)
                        _ = s.addEdge(from: anchorID, to: newStaticPin.id)
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
        self.dragState = ds
    }

    public func endDrag() {
        guard let ds = dragState else { return }

        // Convert temporary detached pins back to free vertices (domain metadata only)
        for (vid, own) in ownership where own == .detachedPin {
            ownership[vid] = .free
        }

        // Normalize around the affected region via ruleset.
        let epicenter = Set(ds.originalVertexPositions.keys).union(ds.newVertices)
        var tx = LoadStateTransaction(newState: engine.currentState, epicenter: epicenter)
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

    // Convenience: find a vertex by pin ownership
    func findVertex(ownedBy ownerID: UUID, pinID: UUID) -> GraphVertex.ID? {
        for (vid, own) in ownership {
            if case .pin(let o, let p) = own, o == ownerID, p == pinID { return vid }
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
                _ = getOrCreatePinVertex(at: absPos, ownerID: ownerID, pinID: pinDef.id)
            }
        }
    }
}
