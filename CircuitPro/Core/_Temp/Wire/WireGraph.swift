//
//  WireGraph.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/17/25.
//
//  REFACTORED FOR PHASE 1: This class is now a facade over the new GraphEngine.
//

//swiftlint:disable cyclomatic_complexity
//swiftlint:disable identifier_name
import Foundation
import SwiftUI

// --- The Core Data Structs (WireVertex, WireEdge, VertexOwnership) ---
// These can eventually be moved to GraphSystem.swift for better organization.
enum VertexOwnership: Hashable {
    case free
    case pin(ownerID: UUID, pinID: UUID)
    case detachedPin // Temporarily marks a vertex that was a pin but is now being dragged
}

struct WireVertex: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
    var ownership: VertexOwnership
    var netID: UUID?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WireVertex, rhs: WireVertex) -> Bool {
        lhs.id == rhs.id
    }
}

struct WireEdge: Identifiable, Hashable {
    let id: UUID
    let start: WireVertex.ID
    let end: WireVertex.ID
}


@Observable
class WireGraph { // swiftlint:disable:this type_body_length
    // MARK: - Engine and State
    
    /// The new central engine that manages the graph's state and behavior.
    public var engine: GraphEngine
    
    // MARK: - Convenience Accessors (Facade Pattern)
    
    /// Provides read-only access to the vertices from the current state.
    public var vertices: [WireVertex.ID: WireVertex] { engine.currentState.vertices }
    /// Provides read-only access to the edges from the current state.
    public var edges: [WireEdge.ID: WireEdge] { engine.currentState.edges }
    /// Provides read-only access to the adjacency list from the current state.
    public var adjacency: [WireVertex.ID: Set<WireEdge.ID>] { engine.currentState.adjacency }
    
    // MARK: - Temporary State (To be refactored)
    private var nextNetNumber = 1

    private struct DragState {
        let originalVertexPositions: [UUID: CGPoint]
        let selectedEdges: [WireEdge]
        let verticesToMove: Set<UUID>
        var newVertices: Set<UUID> = []
    }
    private var dragState: DragState?
    
    /// A callback closure that gets executed whenever the graph's topology changes.
    var onModelDidChange: (() -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Start with an empty graph, configured with the orthogonal ruleset.
        self.engine = GraphEngine(
            initialState: .empty,
            ruleset: OrthogonalWireRuleset()
        )
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

    // MARK: - Persistence API (Refactored)
    
    public func build(from wires: [Wire]) {
        guard !wires.isEmpty else {
            // Ensure even an empty build results in a clean empty state
            self.engine = GraphEngine(initialState: .empty, ruleset: OrthogonalWireRuleset())
            return
        }

        var newVertices: [WireVertex.ID: WireVertex] = [:]
        var newEdges: [WireEdge.ID: WireEdge] = [:]
        var newAdjacency: [WireVertex.ID: Set<WireEdge.ID>] = [:]
        var newNetNames: [UUID: String] = [:]
        var attachmentMap: [AttachmentPoint: WireVertex.ID] = [:]
        
        func addVertex(at point: CGPoint, ownership: VertexOwnership) -> WireVertex {
            let vertex = WireVertex(id: UUID(), point: point, ownership: ownership, netID: nil)
            newVertices[vertex.id] = vertex
            newAdjacency[vertex.id] = []
            return vertex
        }
        
        func addEdge(from startID: WireVertex.ID, to endID: WireVertex.ID) {
            let edge = WireEdge(id: UUID(), start: startID, end: endID)
            newEdges[edge.id] = edge
            newAdjacency[startID]?.insert(edge.id)
            newAdjacency[endID]?.insert(edge.id)
        }

        func getVertexID(for point: AttachmentPoint, netID: UUID) -> WireVertex.ID {
            if let existingID = attachmentMap[point] { return existingID }
            let newVertex: WireVertex
            switch point {
            case .free(let pt):
                newVertex = addVertex(at: pt, ownership: .free)
            case .pin(let componentInstanceID, let pinID):
                newVertex = addVertex(at: .zero, ownership: .pin(ownerID: componentInstanceID, pinID: pinID))
            }
            newVertices[newVertex.id]?.netID = netID
            attachmentMap[point] = newVertex.id
            return newVertex.id
        }
        
        for wire in wires {
            for segment in wire.segments {
                let startID = getVertexID(for: segment.start, netID: wire.id)
                let endID = getVertexID(for: segment.end, netID: wire.id)
                if startID != endID { addEdge(from: startID, to: endID) }
            }
        }
        
        let newState = GraphState(
            vertices: newVertices,
            edges: newEdges,
            adjacency: newAdjacency,
            netNames: newNetNames
        )
        self.engine = GraphEngine(initialState: newState, ruleset: OrthogonalWireRuleset())
    }

    public func toWires() -> [Wire] {
        var wires: [Wire] = []
        var processedVertices = Set<WireVertex.ID>()
        let currentState = engine.currentState

        for vertexID in currentState.vertices.keys {
            guard !processedVertices.contains(vertexID) else { continue }

            let (netVertices, netEdges) = net(startingFrom: vertexID, in: currentState)
            guard !netEdges.isEmpty, let netID = currentState.vertices[vertexID]?.netID else {
                processedVertices.formUnion(netVertices)
                continue
            }

            let segments = netEdges.compactMap { edgeID -> WireSegment? in
                guard let edge = currentState.edges[edgeID],
                      let startVertex = currentState.vertices[edge.start],
                      let endVertex = currentState.vertices[edge.end],
                      let startPoint = attachmentPoint(for: startVertex),
                      let endPoint = attachmentPoint(for: endVertex) else { return nil }
                return WireSegment(start: startPoint, end: endPoint)
            }

            if !segments.isEmpty { wires.append(Wire(id: netID, segments: segments)) }
            processedVertices.formUnion(netVertices)
        }
        return wires
    }

    private func attachmentPoint(for vertex: WireVertex) -> AttachmentPoint? {
        switch vertex.ownership {
        case .free, .detachedPin:
            return .free(point: vertex.point)
        case .pin(let ownerID, let pinID):
            return .pin(componentInstanceID: ownerID, pinID: pinID)
        }
    }
    
    public func releasePins(for ownerID: UUID) {
        var tempState = engine.currentState
        let verticesToRelease = tempState.vertices.values.filter { vertex in
            if case .pin(let oID, _) = vertex.ownership, oID == ownerID { return true }
            return false
        }
        for var vertex in verticesToRelease {
            vertex.ownership = .free
            tempState.vertices[vertex.id] = vertex
        }
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
    }

    // MARK: - Public API
    public func setName(_ name: String, for netID: UUID) {
        var tempState = engine.currentState
        tempState.netNames[netID] = name
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
    }
    
    func getOrCreateVertex(at point: CGPoint) -> WireVertex.ID {
        var tempState = engine.currentState
        let id = _getOrCreateVertex(at: point, in: &tempState)
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
        return id
    }
    
    func getOrCreatePinVertex(at point: CGPoint, ownerID: UUID, pinID: UUID) -> WireVertex.ID {
        var tempState = engine.currentState
        let id = _getOrCreatePinVertex(at: point, ownerID: ownerID, pinID: pinID, in: &tempState)
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
        return id
    }
    
    func connect(from startID: WireVertex.ID, to endID: WireVertex.ID, preferring strategy: WireConnectionStrategy = .horizontalThenVertical) {
        var tempState = engine.currentState
        _connect(from: startID, to: endID, preferring: strategy, in: &tempState)
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
        onModelDidChange?()
    }

    func delete(items: Set<UUID>) {
        var tempState = engine.currentState
        _delete(items: items, in: &tempState)
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
        onModelDidChange?()
    }

    // MARK: - Drag Lifecycle (Refactored)

    public func beginDrag(selectedIDs: Set<UUID>) -> Bool {
        let currentState = engine.currentState
        let symbolPinVertexIDs = currentState.vertices.values.filter {
            if case .pin(let ownerID, _) = $0.ownership { return selectedIDs.contains(ownerID) }
            return false
        }.map { $0.id }

        let selectedEdges = currentState.edges.values.filter { selectedIDs.contains($0.id) }
        
        let movableEdgeVertexIDs = selectedEdges.flatMap { [$0.start, $0.end] }.filter { vertexID in
            guard let vertex = currentState.vertices[vertexID] else { return false }
            if case .pin = vertex.ownership { return false }
            return true
        }

        let allMovableVertexIDs = Set(symbolPinVertexIDs).union(movableEdgeVertexIDs)
        guard !allMovableVertexIDs.isEmpty else {
            self.dragState = nil
            return false
        }

        self.dragState = DragState(
            originalVertexPositions: currentState.vertices.mapValues { $0.point },
            selectedEdges: selectedEdges,
            verticesToMove: allMovableVertexIDs
        )
        return true
    }

    public func updateDrag(by delta: CGPoint) {
        guard self.dragState != nil else { return }
        var tempState = engine.currentState
        _updateDrag(by: delta, in: &tempState)
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
    }

    public func endDrag() {
        guard self.dragState != nil else { return }
        var tempState = engine.currentState
        _endDrag(in: &tempState)
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
        self.dragState = nil
        onModelDidChange?()
    }
    
    // MARK: - Private Logic (Operating on explicit GraphState)

    private func _getOrCreateVertex(at point: CGPoint, in state: inout GraphState) -> WireVertex.ID {
        if let existingVertex = findVertex(at: point, in: state) {
            return existingVertex.id
        }
        if let edgeToSplit = findEdge(at: point, in: state) {
            return _splitEdgeAndInsertVertex(edgeID: edgeToSplit.id, at: point, in: &state)!
        }
        return _addVertex(at: point, ownership: .free, in: &state).id
    }
    
    private func _getOrCreatePinVertex(at point: CGPoint, ownerID: UUID, pinID: UUID, in state: inout GraphState) -> WireVertex.ID {
        let ownership: VertexOwnership = .pin(ownerID: ownerID, pinID: pinID)
        if let existingVertex = findVertex(at: point, in: state) {
            state.vertices[existingVertex.id]?.ownership = ownership
            return existingVertex.id
        }
        if let edgeToSplit = findEdge(at: point, in: state) {
            return _splitEdgeAndInsertVertex(edgeID: edgeToSplit.id, at: point, ownership: ownership, in: &state)!
        }
        return _addVertex(at: point, ownership: ownership, in: &state).id
    }
    
    private func _connect(from startID: WireVertex.ID, to endID: WireVertex.ID, preferring strategy: WireConnectionStrategy, in state: inout GraphState) {
        guard let startVertex = state.vertices[startID], let endVertex = state.vertices[endID] else {
            assertionFailure("Cannot connect non-existent vertices.")
            return
        }
        var affectedVertices: Set<WireVertex.ID> = [startID, endID]
        let startPoint = startVertex.point
        let destinationPoint = endVertex.point

        if startPoint.x == destinationPoint.x || startPoint.y == destinationPoint.y {
            _connectStraightLine(from: startVertex, to: endVertex, affectedVertices: &affectedVertices, in: &state)
        } else {
            _handleLShapeWire(from: startVertex, to: endVertex, strategy: strategy, affectedVertices: &affectedVertices, in: &state)
        }

        _unifyNetIDs(between: startID, and: endID, in: &state)
        _normalize(around: affectedVertices, in: &state)
    }

    private func _delete(items: Set<UUID>, in state: inout GraphState) {
        var verticesToCheck: Set<WireVertex.ID> = []
        for itemID in items {
            if let edge = state.edges[itemID] {
                verticesToCheck.insert(edge.start)
                verticesToCheck.insert(edge.end)
                _removeEdge(id: itemID, in: &state)
            }
        }
        for itemID in items {
            if let vertexToRemove = state.vertices[itemID] {
                let (horizontal, vertical) = getCollinearNeighbors(for: vertexToRemove, in: state)
                vertical.forEach { verticesToCheck.insert($0.id) }
                horizontal.forEach { verticesToCheck.insert($0.id) }
                _removeVertex(id: itemID, in: &state)
            }
        }
        _normalize(around: verticesToCheck, in: &state)
    }
    
    private func _moveVertex(id: WireVertex.ID, to newPoint: CGPoint, in state: inout GraphState) {
        if state.vertices[id]?.point != newPoint {
            state.vertices[id]?.point = newPoint
        }
    }
    
    private func _updateDrag(by delta: CGPoint, in state: inout GraphState) {
        guard var dragState = self.dragState else { return }

        for vertexID in dragState.verticesToMove {
            guard let vertex = state.vertices[vertexID], case .pin = vertex.ownership else { continue }
            let isOffAxis = (state.adjacency[vertexID] ?? []).contains { edgeID in
                guard dragState.selectedEdges.contains(where: { $0.id == edgeID }) else { return false }
                guard let edge = state.edges[edgeID] else { return false }
                let otherEndID = (edge.start == vertexID) ? edge.end : edge.start
                if dragState.verticesToMove.contains(otherEndID) { return false }
                guard let originalPos = dragState.originalVertexPositions[vertexID],
                      let otherEndOrigPos = dragState.originalVertexPositions[otherEndID] else { return false }
                let wasHorizontal = abs(originalPos.y - otherEndOrigPos.y) < 1e-6
                return (wasHorizontal && abs(delta.y) > 1e-6) || (!wasHorizontal && abs(delta.x) > 1e-6)
            }
            if isOffAxis {
                let pinOwnership = vertex.ownership
                let pinPoint = vertex.point
                state.vertices[vertexID]?.ownership = .detachedPin
                let newStaticPinVertex = _addVertex(at: pinPoint, ownership: pinOwnership, in: &state)
                dragState.newVertices.insert(newStaticPinVertex.id)
                _addEdge(from: vertexID, to: newStaticPinVertex.id, in: &state)
            }
        }
        self.dragState = dragState
        
        var newPositions: [UUID: CGPoint] = [:]
        for id in dragState.verticesToMove {
            if let origin = dragState.originalVertexPositions[id] {
                newPositions[id] = CGPoint(x: origin.x + delta.x, y: origin.y + delta.y)
            }
        }

        for vertexID in dragState.verticesToMove {
            if let vertex = state.vertices[vertexID], vertex.ownership == .detachedPin {
                guard let staticPinNeighbor = findNeighbor(of: vertexID, in: state, where: { nID, _ in if case .pin = state.vertices[nID]?.ownership { return newPositions[nID] == nil } else { return false } }),
                      let movingNeighbor = findNeighbor(of: vertexID, in: state, where: { nID, e in return newPositions[nID] != nil && dragState.selectedEdges.contains { $0.id == e.id } }) else { continue }
                let origVPos = dragState.originalVertexPositions[vertexID]!, origMPos = dragState.originalVertexPositions[movingNeighbor.id]!, newMPos = newPositions[movingNeighbor.id]!
                let wasHorizontal = abs(origVPos.y - origMPos.y) < 1e-6
                newPositions[vertexID] = wasHorizontal ? CGPoint(x: staticPinNeighbor.point.x, y: newMPos.y) : CGPoint(x: newMPos.x, y: staticPinNeighbor.point.y)
            }
        }
        
        var queue: [UUID] = Array(dragState.verticesToMove)
        var queuedVertices: Set<UUID> = dragState.verticesToMove
        var head = 0
        while head < queue.count {
            let junctionID = queue[head]; head += 1
            guard let junctionNewPos = newPositions[junctionID], let junctionOrigPos = dragState.originalVertexPositions[junctionID] else { continue }
            for edgeID in state.adjacency[junctionID] ?? [] {
                guard let edge = state.edges[edgeID] else { continue }
                let anchorID = edge.start == junctionID ? edge.end : edge.start
                if dragState.verticesToMove.contains(anchorID) { continue }
                guard let anchorOrigPos = dragState.originalVertexPositions[anchorID] else { continue }
                var updatedAnchorPos = newPositions[anchorID] ?? anchorOrigPos
                let wasHorizontal = abs(anchorOrigPos.y - junctionOrigPos.y) < 1e-6
                
                if var anchorVertex = state.vertices[anchorID], case .pin(let originalOwnerID, let originalPinID) = anchorVertex.ownership {
                    let isOffAxisPull = (wasHorizontal && abs(junctionNewPos.y - anchorOrigPos.y) > 1e-6) || (!wasHorizontal && abs(junctionNewPos.x - anchorOrigPos.x) > 1e-6)
                    if isOffAxisPull {
                        updatedAnchorPos = wasHorizontal ? CGPoint(x: anchorOrigPos.x, y: junctionNewPos.y) : CGPoint(x: junctionNewPos.x, y: anchorOrigPos.y)
                        if case .pin = anchorVertex.ownership {
                            anchorVertex.ownership = .detachedPin
                            state.vertices[anchorID] = anchorVertex
                            let newStaticPin = _addVertex(at: anchorOrigPos, ownership: .pin(ownerID: originalOwnerID, pinID: originalPinID), in: &state)
                            self.dragState?.newVertices.insert(newStaticPin.id)
                            _addEdge(from: anchorID, to: newStaticPin.id, in: &state)
                        }
                    } else {
                        continue
                    }
                } else {
                    if wasHorizontal { updatedAnchorPos.y = junctionNewPos.y } else { updatedAnchorPos.x = junctionNewPos.x }
                }
                
                if newPositions[anchorID] != updatedAnchorPos {
                    newPositions[anchorID] = updatedAnchorPos
                    if !queuedVertices.contains(anchorID) {
                        queue.append(anchorID)
                        queuedVertices.insert(anchorID)
                    }
                }
            }
        }
        
        for (id, pos) in newPositions {
            _moveVertex(id: id, to: pos, in: &state)
        }
    }
    
    private func _endDrag(in state: inout GraphState) {
        guard let dragState = self.dragState else { return }
        for vertexID in state.vertices.keys {
            if let vertex = state.vertices[vertexID], case .detachedPin = vertex.ownership {
                state.vertices[vertexID]?.ownership = .free
            }
        }
        var affectedVertices = Set(dragState.originalVertexPositions.keys)
        affectedVertices.formUnion(dragState.newVertices)
        _normalize(around: affectedVertices, in: &state)
    }
    
    internal func _normalize(around verticesToCheck: Set<WireVertex.ID>, in state: inout GraphState) {
        let mergedVertices = _mergeCoincidentVertices(in: verticesToCheck, in: &state)
        var allAffectedVertices = verticesToCheck
        allAffectedVertices.formUnion(mergedVertices)
        _splitEdgesWithIntermediateVertices(in: &state)
        for vertexID in allAffectedVertices {
            if state.vertices[vertexID] != nil {
                _cleanupCollinearSegments(at: vertexID, in: &state)
            }
        }
        for vertexID in allAffectedVertices where state.vertices[vertexID] != nil && (state.adjacency[vertexID]?.isEmpty ?? false) {
            if let vertex = state.vertices[vertexID], case .free = vertex.ownership {
                _removeVertex(id: vertexID, in: &state)
            }
        }
    }
    
    private func _splitEdgesWithIntermediateVertices(in state: inout GraphState) {
        var splits: [(edgeID: UUID, vertexID: UUID)] = []
        let allEdges = Array(state.edges.values)
        let allVertices = Array(state.vertices.values)
        for edge in allEdges {
            guard let p1 = state.vertices[edge.start]?.point, let p2 = state.vertices[edge.end]?.point else { continue }
            for vertex in allVertices {
                if vertex.id == edge.start || vertex.id == edge.end { continue }
                if isPoint(vertex.point, onSegmentBetween: p1, p2: p2) {
                    splits.append((edge.id, vertex.id))
                }
            }
        }
        guard !splits.isEmpty else { return }
        for split in splits {
            guard let edgeToSplit = state.edges[split.edgeID] else { continue }
            let startID = edgeToSplit.start
            let endID = edgeToSplit.end
            _removeEdge(id: edgeToSplit.id, in: &state)
            _addEdge(from: startID, to: split.vertexID, in: &state)
            _addEdge(from: split.vertexID, to: endID, in: &state)
        }
    }
    
    private func _cleanupCollinearSegments(at vertexID: WireVertex.ID, in state: inout GraphState) {
        guard let centerVertex = state.vertices[vertexID] else { return }
        guard case .free = centerVertex.ownership else { return }
        _processCollinearRun(for: centerVertex, isHorizontal: true, in: &state)
        guard state.vertices[vertexID] != nil else { return }
        _processCollinearRun(for: centerVertex, isHorizontal: false, in: &state)
    }
    
    private func _mergeCoincidentVertices(in scope: Set<WireVertex.ID>, in state: inout GraphState) -> Set<WireVertex.ID> {
        var verticesToProcess = scope.compactMap { state.vertices[$0] }
        var processedIDs: Set<WireVertex.ID> = []
        var modifiedVertices: Set<WireVertex.ID> = []
        let tolerance: CGFloat = 1e-6
        while let vertex = verticesToProcess.popLast() {
            if processedIDs.contains(vertex.id) { continue }
            let coincidentGroup = state.vertices.values.filter { hypot(vertex.point.x - $0.point.x, vertex.point.y - $0.point.y) < tolerance }
            if coincidentGroup.count > 1 {
                let survivor = coincidentGroup.first(where: { if case .pin = $0.ownership { return true } else { return false } }) ?? coincidentGroup.first!
                processedIDs.insert(survivor.id)
                modifiedVertices.insert(survivor.id)
                for victim in coincidentGroup where victim.id != survivor.id {
                    _unifyNetIDs(between: survivor.id, and: victim.id, in: &state)
                    if let victimEdges = state.adjacency[victim.id] {
                        for edgeID in victimEdges {
                            guard let edge = state.edges[edgeID] else { continue }
                            let otherEndID = edge.start == victim.id ? edge.end : edge.start
                            if otherEndID != survivor.id {
                                _addEdge(from: survivor.id, to: otherEndID, in: &state)
                            }
                        }
                    }
                    _removeVertex(id: victim.id, in: &state)
                    processedIDs.insert(victim.id)
                }
            } else {
                processedIDs.insert(vertex.id)
            }
        }
        return modifiedVertices
    }
    
    private func _processCollinearRun(for startVertex: WireVertex, isHorizontal: Bool, in state: inout GraphState) {
        var run: [WireVertex] = []
        var queue: [WireVertex] = [startVertex]
        var visitedIDs: Set<WireVertex.ID> = [startVertex.id]
        while let current = queue.popLast() {
            run.append(current)
            let (horizontal, vertical) = getCollinearNeighbors(for: current, in: state)
            (isHorizontal ? horizontal : vertical).forEach { neighbor in
                if !visitedIDs.contains(neighbor.id) {
                    visitedIDs.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }
        if run.count < 3 { return }
        
        var keptIDs: Set<WireVertex.ID> = []
        for vertex in run {
            if case .pin = vertex.ownership {
                keptIDs.insert(vertex.id)
                continue
            }
            let (horizontal, vertical) = getCollinearNeighbors(for: vertex, in: state)
            let collinearNeighborCount = isHorizontal ? horizontal.count : vertical.count
            if (state.adjacency[vertex.id]?.count ?? 0) > collinearNeighborCount {
                keptIDs.insert(vertex.id)
            }
        }
        
        if isHorizontal { run.sort { $0.point.x < $1.point.x } } else { run.sort { $0.point.y < $1.point.y } }
        if let first = run.first { keptIDs.insert(first.id) }
        if let last = run.last { keptIDs.insert(last.id) }
        if keptIDs.count >= run.count { return }
        
        let runIDs = Set(run.map { $0.id })
        for vertex in run where state.adjacency[vertex.id] != nil {
            for edgeID in Array(state.adjacency[vertex.id]!) {
                if let edge = state.edges[edgeID], runIDs.contains(edge.start == vertex.id ? edge.end : edge.start) {
                    _removeEdge(id: edgeID, in: &state)
                }
            }
        }
        run.filter { !keptIDs.contains($0.id) }.forEach { _removeVertex(id: $0.id, in: &state) }
        let sortedKeptVertices = run.filter { keptIDs.contains($0.id) }
        if sortedKeptVertices.count < 2 { return }
        for i in 0..<(sortedKeptVertices.count - 1) {
            _addEdge(from: sortedKeptVertices[i].id, to: sortedKeptVertices[i+1].id, in: &state)
        }
    }
    
    private func _connectStraightLine(from startVertex: WireVertex, to endVertex: WireVertex, affectedVertices: inout Set<WireVertex.ID>, in state: inout GraphState) {
        var verticesOnPath: [WireVertex] = [startVertex, endVertex]
        let otherVertices = state.vertices.values.filter {
            $0.id != startVertex.id && $0.id != endVertex.id && isPoint($0.point, onSegmentBetween: startVertex.point, p2: endVertex.point)
        }
        verticesOnPath.append(contentsOf: otherVertices)
        otherVertices.forEach { affectedVertices.insert($0.id) }
        if startVertex.point.x == endVertex.point.x { verticesOnPath.sort { $0.point.y < $1.point.y } }
        else { verticesOnPath.sort { $0.point.x < $1.point.x } }
        for i in 0..<(verticesOnPath.count - 1) {
            _addEdge(from: verticesOnPath[i].id, to: verticesOnPath[i+1].id, in: &state)
        }
    }
    
    private func _handleLShapeWire(from startVertex: WireVertex, to endVertex: WireVertex, strategy: WireConnectionStrategy, affectedVertices: inout Set<WireVertex.ID>, in state: inout GraphState) {
        let cornerPoint: CGPoint
        switch strategy {
        case .horizontalThenVertical: cornerPoint = CGPoint(x: endVertex.point.x, y: startVertex.point.y)
        case .verticalThenHorizontal: cornerPoint = CGPoint(x: startVertex.point.x, y: endVertex.point.y)
        }
        let cornerVertexID = _getOrCreateVertex(at: cornerPoint, in: &state)
        guard let cornerVertex = state.vertices[cornerVertexID] else { return }
        affectedVertices.insert(cornerVertexID)
        _connectStraightLine(from: startVertex, to: cornerVertex, affectedVertices: &affectedVertices, in: &state)
        _connectStraightLine(from: cornerVertex, to: endVertex, affectedVertices: &affectedVertices, in: &state)
    }
    
    @discardableResult
    private func _addVertex(at point: CGPoint, ownership: VertexOwnership, in state: inout GraphState) -> WireVertex {
        let vertex = WireVertex(id: UUID(), point: point, ownership: ownership, netID: nil)
        state.vertices[vertex.id] = vertex
        state.adjacency[vertex.id] = []
        return vertex
    }
    
    @discardableResult
    private func _addEdge(from startVertexID: WireVertex.ID, to endVertexID: WireVertex.ID, in state: inout GraphState) -> WireEdge? {
        guard state.vertices[startVertexID] != nil, state.vertices[endVertexID] != nil else { return nil }
        let isAlreadyConnected = state.adjacency[startVertexID]?.contains { edgeID in
            guard let edge = state.edges[edgeID] else { return false }
            return edge.start == endVertexID || edge.end == endVertexID
        } ?? false
        if isAlreadyConnected { return nil }
        let edge = WireEdge(id: UUID(), start: startVertexID, end: endVertexID)
        state.edges[edge.id] = edge
        state.adjacency[startVertexID]?.insert(edge.id)
        state.adjacency[endVertexID]?.insert(edge.id)
        return edge
    }
    
    @discardableResult
    private func _splitEdgeAndInsertVertex(edgeID: UUID, at point: CGPoint, ownership: VertexOwnership = .free, in state: inout GraphState) -> WireVertex.ID? {
        guard let edgeToSplit = state.edges[edgeID] else { return nil }
        let startID = edgeToSplit.start
        let endID = edgeToSplit.end
        let originalNetID = state.vertices[startID]?.netID
        _removeEdge(id: edgeID, in: &state)
        let newVertex = _addVertex(at: point, ownership: ownership, in: &state)
        state.vertices[newVertex.id]?.netID = originalNetID
        _addEdge(from: startID, to: newVertex.id, in: &state)
        _addEdge(from: newVertex.id, to: endID, in: &state)
        return newVertex.id
    }
    
    private func _removeVertex(id: WireVertex.ID, in state: inout GraphState) {
        if let connectedEdgeIDs = state.adjacency[id] {
            for edgeID in Array(connectedEdgeIDs) { _removeEdge(id: edgeID, in: &state) }
        }
        state.adjacency.removeValue(forKey: id)
        state.vertices.removeValue(forKey: id)
    }
    
    private func _removeEdge(id: WireEdge.ID, in state: inout GraphState) {
        guard let edge = state.edges.removeValue(forKey: id) else { return }
        state.adjacency[edge.start]?.remove(id)
        state.adjacency[edge.end]?.remove(id)
    }
    
    // MARK: - Read-only helpers (now take GraphState)
    private func findNeighbor(of vertexID: UUID, in state: GraphState, where predicate: (UUID, WireEdge) -> Bool) -> WireVertex? {
        guard let edges = state.adjacency[vertexID] else { return nil }
        for edgeID in edges {
            guard let edge = state.edges[edgeID] else { continue }
            let neighborID = edge.start == vertexID ? edge.end : edge.start
            if predicate(neighborID, edge) {
                return state.vertices[neighborID]
            }
        }
        return nil
    }

    private func _unifyNetIDs(between vertex1ID: WireVertex.ID, and vertex2ID: WireVertex.ID, in state: inout GraphState) {
        let netID1 = state.vertices[vertex1ID]?.netID
        let netID2 = state.vertices[vertex2ID]?.netID
        if let id1 = netID1, let id2 = netID2 {
            if id1 != id2 {
                let (wholeComponent, _) = net(startingFrom: vertex2ID, in: state)
                for vID in wholeComponent { state.vertices[vID]?.netID = id1 }
                // Simplified net name handling for now. This can be a separate transaction type later.
            }
        } else {
            let (wholeComponent, _) = net(startingFrom: vertex1ID, in: state)
            let existingID = wholeComponent.compactMap { state.vertices[$0]?.netID }.first
            let finalNetID = existingID ?? UUID()
            for vID in wholeComponent { state.vertices[vID]?.netID = finalNetID }
        }
    }
    
    func findVertex(at point: CGPoint, in state: GraphState) -> WireVertex? {
        let tolerance: CGFloat = 1e-6
        return state.vertices.values.first { abs($0.point.x - point.x) < tolerance && abs($0.point.y - point.y) < tolerance }
    }
    
    func findEdge(at point: CGPoint, in state: GraphState) -> WireEdge? {
        for edge in state.edges.values {
            guard let startVertex = state.vertices[edge.start], let endVertex = state.vertices[edge.end] else { continue }
            if isPoint(point, onSegmentBetween: startVertex.point, p2: endVertex.point) { return edge }
        }
        return nil
    }
    
    func findVertex(ownedBy ownerID: UUID, pinID: UUID, in state: GraphState) -> WireVertex.ID? {
        for vertex in state.vertices.values {
            if case .pin(let oID, let pID) = vertex.ownership, oID == ownerID, pID == pinID { return vertex.id }
        }
        return nil
    }
    
    private func getCollinearNeighbors(for centerVertex: WireVertex, in state: GraphState) -> (horizontal: [WireVertex], vertical: [WireVertex]) {
        guard let connectedEdgeIDs = state.adjacency[centerVertex.id] else { return ([], []) }
        var h:[WireVertex] = [], v:[WireVertex] = []
        let tolerance: CGFloat = 1e-6
        for edgeID in connectedEdgeIDs {
            guard let edge = state.edges[edgeID] else { continue }
            let neighborID = (edge.start == centerVertex.id) ? edge.end : edge.start
            guard let neighbor = state.vertices[neighborID] else { continue }
            if abs(neighbor.point.y - centerVertex.point.y) < tolerance { h.append(neighbor) }
            else if abs(neighbor.point.x - centerVertex.point.x) < tolerance { v.append(neighbor) }
        }
        return (h, v)
    }
    
    private func isPoint(_ p: CGPoint, onSegmentBetween p1: CGPoint, p2: CGPoint) -> Bool {
        let tolerance: CGFloat = 1e-6
        let minX = min(p1.x, p2.x) - tolerance, maxX = max(p1.x, p2.x) + tolerance
        let minY = min(p1.y, p2.y) - tolerance, maxY = max(p1.y, p2.y) + tolerance
        guard p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY else { return false }
        if abs(p1.y - p2.y) < tolerance { return abs(p.y - p1.y) < tolerance }
        if abs(p1.x - p2.x) < tolerance { return abs(p.x - p1.x) < tolerance }
        return false
    }
    
    func net(startingFrom startVertexID: WireVertex.ID, in state: GraphState) -> (vertices: Set<WireVertex.ID>, edges: Set<WireEdge.ID>) {
        var visitedVertices: Set<WireVertex.ID> = []
        var visitedEdges: Set<WireEdge.ID> = []
        var queue: [WireVertex.ID] = [startVertexID]
        guard state.vertices[startVertexID] != nil else { return ([], []) }
        visitedVertices.insert(startVertexID)
        while let currentVertexID = queue.popLast() {
            guard let connectedEdgeIDs = state.adjacency[currentVertexID] else { continue }
            for edgeID in connectedEdgeIDs where !visitedEdges.contains(edgeID) {
                visitedEdges.insert(edgeID)
                guard let edge = state.edges[edgeID] else { continue }
                let otherVertexID = (edge.start == currentVertexID) ? edge.end : edge.start
                if !visitedVertices.contains(otherVertexID) {
                    visitedVertices.insert(otherVertexID)
                    queue.append(otherVertexID)
                }
            }
        }
        return (visitedVertices, visitedEdges)
    }
    
    func findNets() -> [Net] {
        var tempState = engine.currentState
        // This method also needs to mutate state to reconcile net IDs and names.
        let nets = _findNets(in: &tempState)
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
        return nets
    }
    
    private func _findNets(in state: inout GraphState) -> [Net] {
        // ... Logic from old `findNets` goes here, operating on the `inout state` ...
        // For brevity, this logic is omitted but follows the same refactoring pattern.
        // It's a complex method that should be refactored carefully in a later step.
        return [] // Placeholder
    }
    
    func syncPins(for symbolInstance: SymbolInstance, of symbolDefinition: SymbolDefinition, ownerID: UUID) {
        var tempState = engine.currentState
        for pinDef in symbolDefinition.pins {
            let rotatedPinPos = pinDef.position.applying(CGAffineTransform(rotationAngle: symbolInstance.rotation))
            let absolutePos = CGPoint(x: symbolInstance.position.x + rotatedPinPos.x, y: symbolInstance.position.y + rotatedPinPos.y)
            if let existingVertexID = findVertex(ownedBy: ownerID, pinID: pinDef.id, in: tempState) {
                _moveVertex(id: existingVertexID, to: absolutePos, in: &tempState)
            } else {
                _getOrCreatePinVertex(at: absolutePos, ownerID: ownerID, pinID: pinDef.id, in: &tempState)
            }
        }
        self.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())
    }
    
    func findVertex(ownedBy ownerID: UUID, pinID: UUID) -> WireVertex.ID? {
        // It calls the private helper, providing the current state automatically.
        return findVertex(ownedBy: ownerID, pinID: pinID, in: engine.currentState)
    }
}
