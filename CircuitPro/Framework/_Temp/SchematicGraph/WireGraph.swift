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
    private var lastPosition: [UUID: CGPoint] = [:]
    
    private(set) var groupLabels: [UUID: String] = [:]

    // MARK: - UI-only drag state (no normalization during drag)
    private var dragHandler: DragHandler?

    // MARK: - Init
    init() {
          // Build policy without capturing self
          let lookupBox = OwnershipLookupBox()
          let policy = WireVertexPolicy(box: lookupBox)

          let geometry = ManhattanGeometry(step: 1)
          self.engine = GraphEngine(
              initialState: .empty,
              ruleset: OrthogonalGraphRuleset(),
              geometry: geometry,
              policy: policy
          )

          lookupBox.lookup = { [weak self] vid in self?.ownership[vid] }

          // Seed lastPosition
          for (vid, v) in engine.currentState.vertices { lastPosition[vid] = v.point }

          engine.onChange = { [weak self] delta, final in
              guard let self = self else { return }
              let tol = self.engine.geometry.epsilon

              // 1) Remap ownership for deleted pin vertices to the surviving coincident vertex
              for vid in delta.deletedVertices {
                  if let own = self.ownership[vid], let oldPos = self.lastPosition[vid] {
                      // Find a surviving vertex at the same location
                      if let survivor = final.vertices.values.first(where: { p in
                          abs(p.point.x - oldPos.x) < tol && abs(p.point.y - oldPos.y) < tol
                      }) {
                          // Transfer pin ownership to survivor
                          self.ownership[survivor.id] = own
                      }
                      // Drop old mapping
                      self.ownership.removeValue(forKey: vid)
                  }
                  // Clean up lastPosition for deleted IDs
                  self.lastPosition.removeValue(forKey: vid)
              }

              // 2) Update last-known positions for moved/created vertices
              for (vid, (_, to)) in delta.movedVertices {
                  self.lastPosition[vid] = to
              }
              for vid in delta.createdVertices {
                  if let v = final.vertices[vid] {
                      self.lastPosition[vid] = v.point
                  }
                  // Default new vertices to .free if not already set by domain logic
                  if self.ownership[vid] == nil {
                      self.ownership[vid] = .free
                  }
              }

              // 3) Clean up lastPosition entries for any lingering IDs that no longer exist
              for vid in delta.deletedVertices {
                  self.lastPosition.removeValue(forKey: vid)
              }
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
            let v = GraphVertex(id: UUID(), point: point, clusterID: nil)
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
            newVertices[v.id]?.clusterID = groupID
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

        let newState = GraphState(vertices: newVertices, edges: newEdges, adjacency: newAdjacency)
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
            guard !compE.isEmpty, let groupID = s.vertices[vID]?.clusterID else { continue }

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
    
    public func setGroupLabel(_ label: String, for groupID: UUID) {
        var tx = SetGroupLabelTransaction(
            groupID: groupID,
            label: label,
            assign: { [weak self] gid, value in self?.groupLabels[gid] = value }
        )
        _ = engine.execute(transaction: &tx) // metadata-only; rules skipped
    }
    
    public func nets() -> [Net] {
        var nets: [Net] = []
        var processed = Set<UUID>()
        let s = engine.currentState

        for vID in s.vertices.keys {
            guard !processed.contains(vID) else { continue }
            
            let (compV, compE) = net(startingFrom: vID, in: s)
            processed.formUnion(compV)

            // A component must have edges to be considered a wire/net.
            // The clusterID is the net's unique identifier.
            guard !compE.isEmpty, let groupID = s.vertices[vID]?.clusterID else { continue }

            // Use the stored label or generate a default name.
            let netName = groupLabels[groupID] ?? "Net \(groupID.uuidString.prefix(8))"
            nets.append(Net(
                id: groupID,
                name: netName,
                vertexCount: compV.count,
                edgeCount: compE.count
            ))
        }
        return nets
    }

    public func component(for netID: UUID) -> (vertices: Set<UUID>, edges: Set<UUID>) {
        // Find any vertex within the desired net to start the traversal.
        guard let vertexInNet = vertices.values.first(where: { $0.clusterID == netID }) else {
            return ([], [])
        }
        // Use the private helper to find the full connected component.
        return net(startingFrom: vertexInNet.id, in: engine.currentState)
    }

    private func attachmentPoint(for v: GraphVertex) -> AttachmentPoint? {
        switch ownership[v.id] ?? .free {
        case .free, .detachedPin: return .free(point: v.point)
        case .pin(let ownerID, let pinID): return .pin(componentInstanceID: ownerID, pinID: pinID)
        }
    }

    // MARK: - Public API (transactions-first)

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
        // Resolve endpoints into vertices
        var txA = GetOrCreateVertexTransaction(point: startPoint)
        _ = engine.execute(transaction: &txA)
        guard let aID = txA.createdID else { return }

        var txB = GetOrCreateVertexTransaction(point: endPoint)
        _ = engine.execute(transaction: &txB)
        guard let bID = txB.createdID else { return }

        // Connect IDs
        let s: ConnectVerticesTransaction.Strategy = (strategy == .horizontalThenVertical) ? .hThenV : .vThenH
        var tx = ConnectVerticesTransaction(startID: aID, endID: bID, strategy: s)
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
        // Build and configure handler with a frozen snapshot
        let handler = DragHandler(
            state: engine.currentState,
            geometry: engine.geometry,
            lookup: { [weak self] vid in self?.ownership[vid] },
            assign: { [weak self] vid, own in self?.ownership[vid] = own }
        )
        let ok = handler.begin(selectedIDs: selectedIDs)
        if ok {
            self.dragHandler = handler
        } else {
            self.dragHandler = nil
        }
        return ok
    }

    public func updateDrag(by delta: CGPoint) {
        guard let handler = dragHandler else { return }
        let nextState = handler.update(by: delta)
        // Push updated geometry without ruleset normalization
        engine.replaceState(nextState)
    }

    public func endDrag() {
        guard var handler = dragHandler else { return }
        let result = handler.end()

        // Normalize around the affected region via ruleset
        var tx = LoadStateTransaction(newState: result.finalState, epicenter: result.epicenter)
        _ = engine.execute(transaction: &tx)

        self.dragHandler = nil
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
                // Move and reassert ownership so the policy sees a protected vertex
                var tx = MoveVertexTransaction(id: existingID, newPoint: absPos)
                _ = engine.execute(transaction: &tx)
                ownership[existingID] = .pin(ownerID: ownerID, pinID: pinDef.id)
            } else {
                _ = getOrCreatePinVertex(at: absPos, ownerID: ownerID, pinID: pinDef.id)
            }
        }
    }
}
