//
//  WireEngine.swift
//  CircuitPro
//
//  Created by Codex on 9/21/25.
//

import Foundation
import SwiftUI

final class WireEngine {
    // MARK: - Engine and State
    let graph: Graph
    let engine: GraphEngine
    private let geometry: GeometryPolicy
    private let ownershipBox = OwnershipLookupBox()

    private var ownership: [UUID: VertexOwnership] = [:]
    private var lastPosition: [UUID: CGPoint] = [:]
    private var dragHandler: DragHandler?

    // Read-only convenience accessors to current state
    var vertices: [GraphVertex.ID: GraphVertex] { engine.currentState.vertices }
    var edges: [GraphEdge.ID: GraphEdge] { engine.currentState.edges }
    var adjacency: [GraphVertex.ID: Set<GraphEdge.ID>] { engine.currentState.adjacency }

    private(set) var groupLabels: [UUID: String] = [:]

    // MARK: - Init
    init(graph: Graph) {
        self.graph = graph
        self.geometry = ManhattanGeometry(step: 1)
        let policy = WireVertexPolicy(box: ownershipBox)
        self.engine = GraphEngine(
            initialState: .empty,
            ruleset: OrthogonalGraphRuleset(),
            geometry: geometry,
            policy: policy
        )

        ownershipBox.lookup = { [weak self] vid in
            self?.ownership[vid]
        }

        engine.onChange = { [weak self] delta, final in
            self?.handleEngineDelta(delta, final: final)
        }
    }

    // MARK: - Net Definition
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

    func build(from wires: [Wire]) {
        let previousSelection = graph.selection
        guard !wires.isEmpty else {
            ownership.removeAll()
            lastPosition.removeAll()
            engine.replaceState(.empty)
            restoreSelection(previousSelection)
            return
        }

        var newVertices: [GraphVertex.ID: GraphVertex] = [:]
        var newEdges: [GraphEdge.ID: GraphEdge] = [:]
        var newAdjacency: [GraphVertex.ID: Set<GraphEdge.ID>] = [:]
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

        ownership = newOwnership
        let newState = GraphState(vertices: newVertices, edges: newEdges, adjacency: newAdjacency)
        engine.replaceState(newState)
        restoreSelection(previousSelection)
    }

    func toWires() -> [Wire] {
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

    func setGroupLabel(_ label: String, for groupID: UUID) {
        var tx = SetGroupLabelTransaction(
            groupID: groupID,
            label: label,
            assign: { [weak self] gid, value in self?.groupLabels[gid] = value }
        )
        _ = engine.execute(transaction: &tx)
    }

    func nets() -> [Net] {
        var nets: [Net] = []
        var processed = Set<UUID>()
        let s = engine.currentState

        for vID in s.vertices.keys {
            guard !processed.contains(vID) else { continue }

            let (compV, compE) = net(startingFrom: vID, in: s)
            processed.formUnion(compV)
            guard !compE.isEmpty, let groupID = s.vertices[vID]?.clusterID else { continue }

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

    func component(for netID: UUID) -> (vertices: Set<UUID>, edges: Set<UUID>) {
        guard let vertexInNet = vertices.values.first(where: { $0.clusterID == netID }) else {
            return ([], [])
        }
        return net(startingFrom: vertexInNet.id, in: engine.currentState)
    }

    // MARK: - Public API (transactions-first)

    func connect(from startPoint: CGPoint,
                 to endPoint: CGPoint,
                 preferring strategy: WireConnectionStrategy = .horizontalThenVertical) {
        var txA = GetOrCreateVertexTransaction(point: startPoint)
        _ = engine.execute(transaction: &txA)
        guard let aID = txA.createdID else { return }

        var txB = GetOrCreateVertexTransaction(point: endPoint)
        _ = engine.execute(transaction: &txB)
        guard let bID = txB.createdID else { return }

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

    func beginDrag(selectedIDs: Set<UUID>) -> Bool {
        let handler = DragHandler(
            state: engine.currentState,
            geometry: engine.geometry,
            lookup: { [weak self] vid in self?.ownership[vid] },
            assign: { [weak self] vid, own in self?.setOwnership(own, for: vid) }
        )
        let ok = handler.begin(selectedIDs: selectedIDs)
        if ok {
            self.dragHandler = handler
        } else {
            self.dragHandler = nil
        }
        return ok
    }

    func updateDrag(by delta: CGPoint) {
        guard let handler = dragHandler else { return }
        let nextState = handler.update(by: delta)
        engine.replaceState(nextState)
    }

    func endDrag() {
        guard var handler = dragHandler else { return }
        let result = handler.end()

        var tx = LoadStateTransaction(newState: result.finalState, epicenter: result.epicenter)
        _ = engine.execute(transaction: &tx)

        self.dragHandler = nil
    }

    // MARK: - Pin Sync

    func findVertex(ownedBy ownerID: UUID, pinID: UUID) -> GraphVertex.ID? {
        for (vid, own) in ownership {
            if case .pin(let o, let p) = own, o == ownerID, p == pinID { return vid }
        }
        return nil
    }

    func syncPins(for symbolInstance: SymbolInstance, of symbolDefinition: SymbolDefinition, ownerID: UUID) {
        for pinDef in symbolDefinition.pins {
            let rotated = pinDef.position.applying(CGAffineTransform(rotationAngle: symbolInstance.rotation))
            let absPos = CGPoint(x: symbolInstance.position.x + rotated.x, y: symbolInstance.position.y + rotated.y)

            if let existingID = findVertex(ownedBy: ownerID, pinID: pinDef.id) {
                var tx = MoveVertexTransaction(id: existingID, newPoint: absPos)
                _ = engine.execute(transaction: &tx)
                setOwnership(.pin(ownerID: ownerID, pinID: pinDef.id), for: existingID)
            } else {
                _ = getOrCreatePinVertex(at: absPos, ownerID: ownerID, pinID: pinDef.id)
            }
        }
    }

    // MARK: - Private Helpers

    private func attachmentPoint(for v: GraphVertex) -> AttachmentPoint? {
        switch ownership[v.id] ?? .free {
        case .free, .detachedPin: return .free(point: v.point)
        case .pin(let ownerID, let pinID): return .pin(componentInstanceID: ownerID, pinID: pinID)
        }
    }

    private func handleEngineDelta(_ delta: GraphDelta, final: GraphState) {
        let tol = geometry.epsilon

        for vid in delta.deletedVertices {
            if let own = ownership[vid], let oldPos = lastPosition[vid] {
                if case .pin = own,
                   let survivor = final.vertices.values.first(where: { p in
                       abs(p.point.x - oldPos.x) < tol && abs(p.point.y - oldPos.y) < tol
                   }) {
                    setOwnership(own, for: survivor.id)
                }
                ownership.removeValue(forKey: vid)
            }
            lastPosition.removeValue(forKey: vid)
        }

        for (vid, (_, to)) in delta.movedVertices {
            lastPosition[vid] = to
        }
        for vid in delta.createdVertices {
            if let v = final.vertices[vid] {
                lastPosition[vid] = v.point
            }
            if ownership[vid] == nil {
                ownership[vid] = .free
            }
        }

        syncGraphComponents(delta: delta, final: final)
    }

    private func syncGraphComponents(delta: GraphDelta, final: GraphState) {
        for id in delta.deletedEdges {
            graph.removeNode(NodeID(id))
        }
        for id in delta.deletedVertices {
            graph.removeNode(NodeID(id))
        }

        for id in delta.createdVertices {
            guard let v = final.vertices[id] else { continue }
            let nodeID = NodeID(id)
            graph.addNode(nodeID)
            let component = WireVertexComponent(
                point: v.point,
                clusterID: v.clusterID,
                ownership: ownership[id] ?? .free
            )
            graph.setComponent(component, for: nodeID)
        }

        for id in delta.createdEdges {
            guard let e = final.edges[id] else { continue }
            let nodeID = NodeID(id)
            graph.addNode(nodeID)
            let clusterID = final.vertices[e.start]?.clusterID ?? final.vertices[e.end]?.clusterID
            let component = WireEdgeComponent(start: NodeID(e.start), end: NodeID(e.end), clusterID: clusterID)
            graph.setComponent(component, for: nodeID)
        }

        for (id, (_, to)) in delta.movedVertices {
            let nodeID = NodeID(id)
            if var component = graph.component(WireVertexComponent.self, for: nodeID) {
                component.point = to
                graph.setComponent(component, for: nodeID)
            }
        }

        if !delta.changedClusterIDs.isEmpty {
            for (id, change) in delta.changedClusterIDs {
                let nodeID = NodeID(id)
                if var component = graph.component(WireVertexComponent.self, for: nodeID) {
                    component.clusterID = change.to
                    graph.setComponent(component, for: nodeID)
                }
            }
            for (edgeID, edge) in final.edges {
                let nodeID = NodeID(edgeID)
                guard var component = graph.component(WireEdgeComponent.self, for: nodeID) else { continue }
                let clusterID = final.vertices[edge.start]?.clusterID ?? final.vertices[edge.end]?.clusterID
                if component.clusterID != clusterID {
                    component.clusterID = clusterID
                    graph.setComponent(component, for: nodeID)
                }
            }
        }
    }

    private func getOrCreateVertex(at point: CGPoint) -> GraphVertex.ID {
        var tx = GetOrCreateVertexTransaction(point: point)
        _ = engine.execute(transaction: &tx)
        precondition(tx.createdID != nil, "GetOrCreateVertexTransaction must yield an ID")
        return tx.createdID!
    }

    @discardableResult
    private func getOrCreatePinVertex(at point: CGPoint, ownerID: UUID, pinID: UUID) -> GraphVertex.ID {
        let vid = getOrCreateVertex(at: point)
        setOwnership(.pin(ownerID: ownerID, pinID: pinID), for: vid)
        return vid
    }

    private func setOwnership(_ own: VertexOwnership, for id: UUID) {
        ownership[id] = own
        if var component = graph.component(WireVertexComponent.self, for: NodeID(id)) {
            component.ownership = own
            graph.setComponent(component, for: NodeID(id))
        }
    }

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

    private func restoreSelection(_ selection: Set<NodeID>) {
        let restored = selection.filter { graph.nodes.contains($0) }
        if graph.selection != restored {
            graph.selection = restored
        }
    }
}
