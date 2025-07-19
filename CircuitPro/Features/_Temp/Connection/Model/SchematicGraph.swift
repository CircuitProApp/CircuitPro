//
//  SchematicGraph.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/17/25.
//

import Foundation
import SwiftUI

struct ConnectionVertex: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
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
        return addVertex(at: point).id
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
        vertices[id]?.point = newPoint
    }
    
    // MARK: - Graph Normalization
    
    /// Normalizes the graph structure around a set of vertices.
    /// This involves merging coincident vertices and cleaning up collinear segments.
    func normalize(around verticesToCheck: Set<ConnectionVertex.ID>) {
        let mergedVertices = mergeCoincidentVertices(in: verticesToCheck)
        
        var allAffectedVertices = verticesToCheck
        allAffectedVertices.formUnion(mergedVertices)
        
        for vertexID in allAffectedVertices {
            if vertices[vertexID] != nil {
                cleanupCollinearSegments(at: vertexID)
            }
        }
        // A second pass to clean up orphans created by the first pass
        for vertexID in allAffectedVertices where vertices[vertexID] != nil && (adjacency[vertexID]?.isEmpty ?? false) {
            removeVertex(id: vertexID)
        }
    }
    
    private func cleanupCollinearSegments(at vertexID: ConnectionVertex.ID) {
        guard let centerVertex = vertices[vertexID] else { return }
        processCollinearRun(for: centerVertex, isHorizontal: true)
        guard vertices[vertexID] != nil else { return }
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
                let survivor = coincidentGroup.first!
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
        if run.count < 3 { return }

        if isHorizontal { run.sort { $0.point.x < $1.point.x } }
        else { run.sort { $0.point.y < $1.point.y } }

        var keptIDs: Set<ConnectionVertex.ID> = [run.first!.id, run.last!.id]
        for vertex in run.dropFirst().dropLast() {
            let (h, v) = getCollinearNeighbors(for: vertex)
            if (adjacency[vertex.id]?.count ?? 0) > (isHorizontal ? h.count : v.count) {
                keptIDs.insert(vertex.id)
            }
        }
        if keptIDs.count == run.count { return }

        let runIDs = Set(run.map { $0.id })
        for vertex in run where adjacency[vertex.id] != nil {
            for edgeID in Array(adjacency[vertex.id]!) {
                if let edge = edges[edgeID], runIDs.contains(edge.start == vertex.id ? edge.end : edge.start) {
                    removeEdge(id: edgeID)
                }
            }
        }
        
        run.filter { !keptIDs.contains($0.id) }.forEach { removeVertex(id: $0.id) }
        
        let sortedKeptVertices = run.filter { keptIDs.contains($0.id) }
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
    private func addVertex(at point: CGPoint) -> ConnectionVertex {
        let vertex = ConnectionVertex(id: UUID(), point: point)
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
    private func splitEdgeAndInsertVertex(edgeID: UUID, at point: CGPoint) -> ConnectionVertex.ID? {
        guard let edgeToSplit = edges[edgeID] else { return nil }
        let startID = edgeToSplit.start
        let endID = edgeToSplit.end
        removeEdge(id: edgeID)
        let newVertex = addVertex(at: point)
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
