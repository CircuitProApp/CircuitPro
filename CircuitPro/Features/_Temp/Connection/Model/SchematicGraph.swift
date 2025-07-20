//
//  SchematicGraph.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/17/25.
//

import Foundation
import SwiftUI

enum VertexOwnership: Hashable {
    case free
    case pin(symbolID: UUID, pinID: UUID)
}

struct ConnectionVertex: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
    var ownership: VertexOwnership
}

struct ConnectionEdge: Identifiable, Hashable {
    let id: UUID
    let start: ConnectionVertex.ID
    let end: ConnectionVertex.ID
}

@Observable
class SchematicGraph {
    
    // MARK: - Net Definition
    struct Net: Identifiable {
        let id = UUID()
        let vertexCount: Int
        let edgeCount: Int
    }
    
    enum ConnectionStrategy {
        case horizontalThenVertical
        case verticalThenHorizontal
    }
    
    // MARK: - Graph State
    private(set) var vertices: [ConnectionVertex.ID: ConnectionVertex] = [:]
    private(set) var edges: [ConnectionEdge.ID: ConnectionEdge] = [:]
    private(set) var adjacency: [ConnectionVertex.ID: Set<ConnectionEdge.ID>] = [:]

    // MARK: - Drag State
    private struct DragState {
        let originalVertexPositions: [UUID: CGPoint]
        let selectedEdges: [ConnectionEdge]
        let verticesToMove: Set<UUID>
    }
    private var dragState: DragState?

    // MARK: - Public API
    
    /// The authoritative method for getting a vertex for a given point.
    /// It finds an existing vertex, splits an edge if the point is on one, or creates a new vertex.
    func getOrCreateVertex(at point: CGPoint) -> ConnectionVertex.ID {
        if let existingVertex = findVertex(at: point) {
            return existingVertex.id
        }
        if let edgeToSplit = findEdge(at: point) {
            // This point is on an edge, so we must split it.
            return splitEdgeAndInsertVertex(edgeID: edgeToSplit.id, at: point)!
        }
        // The point is in empty space.
        return addVertex(at: point, ownership: .free).id
    }
    
    /// Finds a vertex for a pin, or creates one, promoting a junction if necessary.
    func getOrCreatePinVertex(at point: CGPoint, symbolID: UUID, pinID: UUID) -> ConnectionVertex.ID {
        let ownership: VertexOwnership = .pin(symbolID: symbolID, pinID: pinID)
        if let existingVertex = findVertex(at: point) {
            // A vertex already exists here. We must claim it.
            vertices[existingVertex.id]?.ownership = ownership
            return existingVertex.id
        }
        if let edgeToSplit = findEdge(at: point) {
            // A pin is being placed on an existing wire. Split it and claim the new vertex.
            return splitEdgeAndInsertVertex(edgeID: edgeToSplit.id, at: point, ownership: ownership)!
        }
        // The pin is in empty space.
        return addVertex(at: point, ownership: ownership).id
    }
    
    /// Creates a new orthogonal connection and normalizes the graph.
    func connect(from startID: ConnectionVertex.ID, to endID: ConnectionVertex.ID, preferring strategy: ConnectionStrategy = .horizontalThenVertical) {
        guard let startVertex = vertices[startID], let endVertex = vertices[endID] else {
            assertionFailure("Cannot connect non-existent vertices.")
            return
        }

        var affectedVertices: Set<ConnectionVertex.ID> = [startID, endID]
        let from = startVertex.point
        let to = endVertex.point

        if from.x == to.x || from.y == to.y {
            connectStraightLine(from: startVertex, to: endVertex, affectedVertices: &affectedVertices)
        } else {
            handleLShapeConnection(from: startVertex, to: endVertex, strategy: strategy, affectedVertices: &affectedVertices)
        }
        
        normalize(around: affectedVertices)
    }
    
    /// Deletes items and normalizes the graph.
    func delete(items: Set<UUID>) {
        var verticesToCheck: Set<ConnectionVertex.ID> = []
        for itemID in items {
            if let edge = edges[itemID] {
                verticesToCheck.insert(edge.start)
                verticesToCheck.insert(edge.end)
                removeEdge(id: itemID)
            }
        }
        for itemID in items {
            if let vertexToRemove = vertices[itemID] {
                let (h, v) = getCollinearNeighbors(for: vertexToRemove)
                v.forEach { verticesToCheck.insert($0.id) }
                h.forEach { verticesToCheck.insert($0.id) }
                removeVertex(id: itemID)
            }
        }
        normalize(around: verticesToCheck)
    }
    
    /// Moves a vertex to a new point. This is a low-level operation
    /// that does not perform normalization.
    func moveVertex(id: ConnectionVertex.ID, to newPoint: CGPoint) {
        if vertices[id]?.point != newPoint {
            vertices[id]?.point = newPoint
        }
    }

    // MARK: - Drag Lifecycle
    
    /// Call this when a drag gesture begins.
    /// It caches the initial state of the graph needed for calculations.
    public func beginDrag(selectedIDs: Set<UUID>) {
        // A drag can affect selected edges OR vertices attached to selected symbols.
        
        // 1. Find vertices that are part of selected symbols
        let pinVertices = vertices.values.filter { vertex in
            if case .pin(let symbolID, _) = vertex.ownership {
                return selectedIDs.contains(symbolID)
            }
            return false
        }
        let pinVertexIDs = Set(pinVertices.map(\.id))

        // 2. Find vertices connected to selected edges
        let selectedEdges = self.edges.values.filter { selectedIDs.contains($0.id) }
        let edgeVertexIDs = Set(selectedEdges.flatMap { [$0.start, $0.end] })
        
        let allMovableVertexIDs = pinVertexIDs.union(edgeVertexIDs)
        guard !allMovableVertexIDs.isEmpty else { return }
        
        self.dragState = DragState(
            originalVertexPositions: self.vertices.mapValues { $0.point },
            selectedEdges: selectedEdges,
            verticesToMove: allMovableVertexIDs
        )
    }

    /// Call this repeatedly as the user drags.
    /// It contains the complex BFS logic to update vertex positions.
    public func updateDrag(by delta: CGPoint) {
        guard let state = dragState else { return }

        var newPositions: [UUID: CGPoint] = [:]
        var queue: [UUID] = Array(state.verticesToMove)
        
        // 1. Initial state: selected vertices move freely
        for id in state.verticesToMove {
            if let origin = state.originalVertexPositions[id] {
                newPositions[id] = CGPoint(x: origin.x + delta.x, y: origin.y + delta.y)
            }
        }
        
        // 2. BFS to propagate constraints
        var head = 0
        while head < queue.count {
            let junctionID = queue[head]
            head += 1
            
            guard let junctionNewPos = newPositions[junctionID],
                  let adjacentEdgeIDs = self.adjacency[junctionID] else { continue }

            for edgeID in adjacentEdgeIDs {
                guard let edge = self.edges[edgeID] else { continue }
                
                // If the edge was part of the initial edge selection, its vertices are already moving.
                // If not, it's a constraining edge.
                let isSelectedEdge = state.selectedEdges.contains(where: { $0.id == edgeID })
                if isSelectedEdge { continue }
                
                let anchorID = edge.start == junctionID ? edge.end : edge.start
                if newPositions[anchorID] != nil { continue } // Already processed

                // Pin-owned vertices that aren't part of the selection are immovable anchors.
                if let anchorVertex = vertices[anchorID], case .pin = anchorVertex.ownership {
                    continue
                }

                guard let anchorOrigPos = state.originalVertexPositions[anchorID],
                      let junctionOrigPos = state.originalVertexPositions[junctionID] else { continue }
                
                let wasHorizontal = abs(anchorOrigPos.y - junctionOrigPos.y) < 1e-6
                
                let newAnchorPos: CGPoint
                if wasHorizontal {
                    newAnchorPos = CGPoint(x: anchorOrigPos.x, y: junctionNewPos.y)
                } else { // Was vertical
                    newAnchorPos = CGPoint(x: junctionNewPos.x, y: anchorOrigPos.y)
                }
                
                newPositions[anchorID] = newAnchorPos
                queue.append(anchorID)
            }
        }

        // 3. Atomic update: Apply all calculated positions
        for (id, pos) in newPositions {
            self.moveVertex(id: id, to: pos)
        }
    }

    /// Call this when the drag gesture ends.
    /// It normalizes the graph and cleans up the temporary state.
    public func endDrag() {
        guard let state = dragState else { return }
        
        // Use the original vertex keys to know which part of the graph was affected.
        let affectedVertices = Set(state.originalVertexPositions.keys)
        normalize(around: affectedVertices)
        
        // Clean up
        self.dragState = nil
    }
    
    // MARK: - Graph Normalization
    
    /// Normalizes the graph structure around a set of vertices.
    /// This involves merging coincident vertices and cleaning up collinear segments.
    func normalize(around verticesToCheck: Set<ConnectionVertex.ID>) {
        let mergedVertices = mergeCoincidentVertices(in: verticesToCheck)
        
        var allAffectedVertices = verticesToCheck
        allAffectedVertices.formUnion(mergedVertices)
        
        // First, resolve any overlapping segments that may have been created by the merge.
        // This is crucial for correctly forming T-junctions.
        splitEdgesWithIntermediateVertices()
        
        // Now, clean up any redundant vertices on straight lines.
        for vertexID in allAffectedVertices {
            if vertices[vertexID] != nil {
                cleanupCollinearSegments(at: vertexID)
            }
        }
        // A second pass to clean up orphans created by the first pass
        for vertexID in allAffectedVertices where vertices[vertexID] != nil && (adjacency[vertexID]?.isEmpty ?? false) {
            if case .free = vertices[vertexID]?.ownership {
                removeVertex(id: vertexID)
            }
        }
    }
    
    private func splitEdgesWithIntermediateVertices() {
        var splits: [(edgeID: UUID, vertexID: UUID)] = []
        
        let allEdges = Array(edges.values)
        let allVertices = Array(vertices.values)

        for edge in allEdges {
            guard let p1 = vertices[edge.start]?.point, let p2 = vertices[edge.end]?.point else { continue }
            
            for vertex in allVertices {
                if vertex.id == edge.start || vertex.id == edge.end { continue }
                
                if isPoint(vertex.point, onSegmentBetween: p1, p2: p2) {
                    splits.append((edge.id, vertex.id))
                }
            }
        }
        
        guard !splits.isEmpty else { return }

        for split in splits {
            // The edge might have been removed by a previous split operation in this same loop
            guard let edgeToSplit = edges[split.edgeID] else { continue }
            
            let startID = edgeToSplit.start
            let endID = edgeToSplit.end
            
            removeEdge(id: edgeToSplit.id)
            addEdge(from: startID, to: split.vertexID)
            addEdge(from: split.vertexID, to: endID)
        }
    }
    
    private func cleanupCollinearSegments(at vertexID: ConnectionVertex.ID) {
        guard let centerVertex = vertices[vertexID] else { return }
        // We only clean up free junctions. Pin-owned vertices are sacred.
        guard case .free = centerVertex.ownership else { return }
        processCollinearRun(for: centerVertex, isHorizontal: true)
        guard vertices[vertexID] != nil else { return } // The vertex might have been removed
        processCollinearRun(for: centerVertex, isHorizontal: false)
    }
    
    private func mergeCoincidentVertices(in scope: Set<ConnectionVertex.ID>) -> Set<ConnectionVertex.ID> {
        var verticesToProcess = scope.compactMap { vertices[$0] }
        var processedIDs: Set<ConnectionVertex.ID> = []
        var modifiedVertices: Set<ConnectionVertex.ID> = []
        let tolerance: CGFloat = 1e-6

        while let vertex = verticesToProcess.popLast() {
            if processedIDs.contains(vertex.id) { continue }
            
            let coincidentGroup = vertices.values.filter {
                hypot(vertex.point.x - $0.point.x, vertex.point.y - $0.point.y) < tolerance
            }
            
            if coincidentGroup.count > 1 {
                // Important: A pin-owned vertex always wins and becomes the survivor.
                let survivor = coincidentGroup.first(where: { if case .pin = $0.ownership { return true } else { return false } })
                               ?? coincidentGroup.first!
                
                processedIDs.insert(survivor.id)
                modifiedVertices.insert(survivor.id)
                
                for victim in coincidentGroup where victim.id != survivor.id {
                    if let victimEdges = adjacency[victim.id] {
                        for edgeID in victimEdges {
                            guard let edge = edges[edgeID] else { continue }
                            let otherEndID = edge.start == victim.id ? edge.end : edge.start
                            if otherEndID != survivor.id {
                                addEdge(from: survivor.id, to: otherEndID)
                            }
                        }
                    }
                    removeVertex(id: victim.id)
                    processedIDs.insert(victim.id)
                }
            } else {
                processedIDs.insert(vertex.id)
            }
        }
        return modifiedVertices
    }
    
    private func processCollinearRun(for startVertex: ConnectionVertex, isHorizontal: Bool) {
        var run: [ConnectionVertex] = []
        var queue: [ConnectionVertex] = [startVertex]
        var visitedIDs: Set<ConnectionVertex.ID> = [startVertex.id]

        // 1. Find the entire continuous run of collinear vertices
        while let current = queue.popLast() {
            run.append(current)
            let (h, v) = getCollinearNeighbors(for: current)
            (isHorizontal ? h : v).forEach { neighbor in
                if !visitedIDs.contains(neighbor.id) {
                    visitedIDs.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }
        
        // A run of 2 is just a single segment, which cannot be simplified
        if run.count < 3 { return }

        // 2. Decide which vertices are topologically significant and must be kept
        var keptIDs: Set<ConnectionVertex.ID> = []
        for vertex in run {
            // Always keep pin-owned vertices
            if case .pin = vertex.ownership {
                keptIDs.insert(vertex.id)
                continue
            }
            
            let (h, v) = getCollinearNeighbors(for: vertex)
            let collinearNeighborCount = isHorizontal ? h.count : v.count
            
            // Keep a vertex if it's a branch point (T-junction) or a true net endpoint.
            if (adjacency[vertex.id]?.count ?? 0) > collinearNeighborCount {
                 keptIDs.insert(vertex.id)
            }
        }
        
        // Always preserve the absolute endpoints of the run
        if isHorizontal { run.sort { $0.point.x < $1.point.x } }
        else { run.sort { $0.point.y < $1.point.y } }
        
        if let first = run.first { keptIDs.insert(first.id) }
        if let last = run.last { keptIDs.insert(last.id) }

        // If no simplification is possible, exit
        if keptIDs.count >= run.count { return }

        // 3. Remove all the old edges that were part of the run
        let runIDs = Set(run.map { $0.id })
        for vertex in run where adjacency[vertex.id] != nil {
            for edgeID in Array(adjacency[vertex.id]!) {
                if let edge = edges[edgeID], runIDs.contains(edge.start == vertex.id ? edge.end : edge.start) {
                    removeEdge(id: edgeID)
                }
            }
        }
        
        // 4. Remove the redundant (not kept) vertices
        run.filter { !keptIDs.contains($0.id) }.forEach { removeVertex(id: $0.id) }
        
        // 5. Create new, simplified edges between the kept vertices
        let sortedKeptVertices = run.filter { keptIDs.contains($0.id) }
        if sortedKeptVertices.count < 2 { return }

        for i in 0..<(sortedKeptVertices.count - 1) {
            addEdge(from: sortedKeptVertices[i].id, to: sortedKeptVertices[i+1].id)
        }
    }
    
    // MARK: - Private Implementation
    
    private func connectStraightLine(from startVertex: ConnectionVertex, to endVertex: ConnectionVertex, affectedVertices: inout Set<ConnectionVertex.ID>) {
        var verticesOnPath: [ConnectionVertex] = [startVertex, endVertex]
        let otherVertices = vertices.values.filter {
            $0.id != startVertex.id && $0.id != endVertex.id && isPoint($0.point, onSegmentBetween: startVertex.point, p2: endVertex.point)
        }
        verticesOnPath.append(contentsOf: otherVertices)
        otherVertices.forEach { affectedVertices.insert($0.id) }
        
        if startVertex.point.x == endVertex.point.x { verticesOnPath.sort { $0.point.y < $1.point.y } }
        else { verticesOnPath.sort { $0.point.x < $1.point.x } }
        
        for i in 0..<(verticesOnPath.count - 1) {
            addEdge(from: verticesOnPath[i].id, to: verticesOnPath[i+1].id)
        }
    }

    private func handleLShapeConnection(from startVertex: ConnectionVertex, to endVertex: ConnectionVertex, strategy: ConnectionStrategy, affectedVertices: inout Set<ConnectionVertex.ID>) {
        let cornerPoint: CGPoint
        switch strategy {
        case .horizontalThenVertical: cornerPoint = CGPoint(x: endVertex.point.x, y: startVertex.point.y)
        case .verticalThenHorizontal: cornerPoint = CGPoint(x: startVertex.point.x, y: endVertex.point.y)
        }
        
        let cornerVertexID = getOrCreateVertex(at: cornerPoint)
        guard let cornerVertex = vertices[cornerVertexID] else { return }
        affectedVertices.insert(cornerVertexID)
        
        connectStraightLine(from: startVertex, to: cornerVertex, affectedVertices: &affectedVertices)
        connectStraightLine(from: cornerVertex, to: endVertex, affectedVertices: &affectedVertices)
    }
    
    @discardableResult
    private func addVertex(at point: CGPoint, ownership: VertexOwnership) -> ConnectionVertex {
        let vertex = ConnectionVertex(id: UUID(), point: point, ownership: ownership)
        vertices[vertex.id] = vertex
        adjacency[vertex.id] = []
        return vertex
    }
    
    @discardableResult
    private func addEdge(from startVertexID: ConnectionVertex.ID, to endVertexID: ConnectionVertex.ID) -> ConnectionEdge? {
        guard vertices[startVertexID] != nil, vertices[endVertexID] != nil else { return nil }
        let isAlreadyConnected = adjacency[startVertexID]?.contains { edgeID in
            guard let edge = edges[edgeID] else { return false }
            return edge.start == endVertexID || edge.end == endVertexID
        } ?? false
        if isAlreadyConnected { return nil }
        
        let edge = ConnectionEdge(id: UUID(), start: startVertexID, end: endVertexID)
        edges[edge.id] = edge
        adjacency[startVertexID]?.insert(edge.id)
        adjacency[endVertexID]?.insert(edge.id)
        return edge
    }
    
    @discardableResult
    private func splitEdgeAndInsertVertex(edgeID: UUID, at point: CGPoint, ownership: VertexOwnership = .free) -> ConnectionVertex.ID? {
        guard let edgeToSplit = edges[edgeID] else { return nil }
        let startID = edgeToSplit.start
        let endID = edgeToSplit.end
        removeEdge(id: edgeID)
        let newVertex = addVertex(at: point, ownership: ownership)
        addEdge(from: startID, to: newVertex.id)
        addEdge(from: newVertex.id, to: endID)
        return newVertex.id
    }
    
    private func removeVertex(id: ConnectionVertex.ID) {
        if let connectedEdgeIDs = adjacency[id] {
            for edgeID in Array(connectedEdgeIDs) { removeEdge(id: edgeID) }
        }
        adjacency.removeValue(forKey: id)
        vertices.removeValue(forKey: id)
    }
    
    private func removeEdge(id: ConnectionEdge.ID) {
        guard let edge = edges.removeValue(forKey: id) else { return }
        adjacency[edge.start]?.remove(id)
        adjacency[edge.end]?.remove(id)
    }
    
    // MARK: - Graph Analysis
    func findVertex(at point: CGPoint) -> ConnectionVertex? {
        let tolerance: CGFloat = 1e-6
        return vertices.values.first { v in abs(v.point.x - point.x) < tolerance && abs(v.point.y - point.y) < tolerance }
    }
    
    func findEdge(at point: CGPoint) -> ConnectionEdge? {
        for edge in edges.values {
            guard let startVertex = vertices[edge.start], let endVertex = vertices[edge.end] else { continue }
            if isPoint(point, onSegmentBetween: startVertex.point, p2: endVertex.point) { return edge }
        }
        return nil
    }

    func findVertex(ownedBy symbolID: UUID, pinID: UUID) -> ConnectionVertex.ID? {
        for vertex in vertices.values {
            if case .pin(let sID, let pID) = vertex.ownership, sID == symbolID, pID == pinID {
                return vertex.id
            }
        }
        return nil
    }

    private func getCollinearNeighbors(for centerVertex: ConnectionVertex) -> (horizontal: [ConnectionVertex], vertical: [ConnectionVertex]) {
        guard let connectedEdgeIDs = adjacency[centerVertex.id] else { return ([], []) }
        var h:[ConnectionVertex] = [], v:[ConnectionVertex] = []
        let tolerance: CGFloat = 1e-6
        for edgeID in connectedEdgeIDs {
            guard let edge = edges[edgeID] else { continue }
            let neighborID = (edge.start == centerVertex.id) ? edge.end : edge.start
            guard let neighbor = vertices[neighborID] else { continue }
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
    
    // ... findNets and net(startingFrom:) remain unchanged ...
    func net(startingFrom startVertexID: ConnectionVertex.ID) -> (vertices: Set<ConnectionVertex.ID>, edges: Set<ConnectionEdge.ID>) {
        var visitedVertices: Set<ConnectionVertex.ID> = []
        var visitedEdges: Set<ConnectionEdge.ID> = []
        var queue: [ConnectionVertex.ID] = [startVertexID]
        guard vertices[startVertexID] != nil else { return ([], []) }
        visitedVertices.insert(startVertexID)
        while let currentVertexID = queue.popLast() {
            guard let connectedEdgeIDs = adjacency[currentVertexID] else { continue }
            for edgeID in connectedEdgeIDs where !visitedEdges.contains(edgeID) {
                visitedEdges.insert(edgeID)
                guard let edge = edges[edgeID] else { continue }
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
        var foundNets: [Net] = []
        var unvisitedVertices = Set(vertices.keys)
        while let startVertexID = unvisitedVertices.first {
            let (netVertices, netEdges) = net(startingFrom: startVertexID)
            if !netEdges.isEmpty {
                foundNets.append(Net(vertexCount: netVertices.count, edgeCount: netEdges.count))
            }
            unvisitedVertices.subtract(netVertices)
        }
        return foundNets
    }
}