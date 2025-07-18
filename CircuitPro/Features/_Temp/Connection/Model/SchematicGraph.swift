//
//  SchematicGraph.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
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
    
    private(set) var vertices: [ConnectionVertex.ID: ConnectionVertex] = [:]
    private(set) var edges: [ConnectionEdge.ID: ConnectionEdge] = [:]
    
    /// Adjacency list for efficient graph traversal. Maps a vertex ID to the set of edge IDs connected to it.
    private(set) var adjacency: [ConnectionVertex.ID: Set<ConnectionEdge.ID>] = [:]

    // MARK: - Mutations
    
    /// Adds a new vertex to the graph at a specified point.
    @discardableResult
    func addVertex(at point: CGPoint) -> ConnectionVertex {
        let vertex = ConnectionVertex(id: UUID(), point: point)
        vertices[vertex.id] = vertex
        adjacency[vertex.id] = []
        return vertex
    }
    
    /// Adds a new edge to the graph between two existing vertices.
    @discardableResult
    func addEdge(from startVertexID: ConnectionVertex.ID, to endVertexID: ConnectionVertex.ID) -> ConnectionEdge? {
        guard vertices[startVertexID] != nil, vertices[endVertexID] != nil else {
            // Ensure both vertices exist before creating an edge.
            assertionFailure("Attempted to create an edge with non-existent vertices.")
            return nil
        }
        
        let edge = ConnectionEdge(id: UUID(), start: startVertexID, end: endVertexID)
        edges[edge.id] = edge
        
        // Update the adjacency list for both vertices.
        adjacency[startVertexID]?.insert(edge.id)
        adjacency[endVertexID]?.insert(edge.id)
        
        return edge
    }
    
    /// Creates a new orthogonal connection between two vertices.
    /// This is the authoritative method for creating connections.
    /// - Parameters:
    ///   - startID: The starting vertex of the connection.
    ///   - endID: The ending vertex of the connection.
    ///   - strategy: The preferred routing for the orthogonal connection.
    func connect(from startID: ConnectionVertex.ID, to endID: ConnectionVertex.ID, preferring strategy: ConnectionStrategy = .horizontalThenVertical) {
        guard let startVertex = vertices[startID],
              let endVertex = vertices[endID] else {
            assertionFailure("Cannot connect non-existent vertices.")
            return
        }

        let from = startVertex.point
        let to = endVertex.point

        // If the line is already straight, handle merging with existing segments.
        if from.x == to.x || from.y == to.y {
            // 1. Find all vertices on the path, including the start and end.
            var verticesOnPath = [startVertex, endVertex]
            
            // Find vertices that lie on the segment but are not the start or end.
            let otherVertices = vertices.values.filter {
                $0.id != startID && $0.id != endID &&
                isPoint($0.point, onSegmentBetween: from, p2: to)
            }
            verticesOnPath.append(contentsOf: otherVertices)

            // 2. Sort them by position.
            if from.x == to.x { // Vertical line
                verticesOnPath.sort { $0.point.y < $1.point.y }
            } else { // Horizontal line
                verticesOnPath.sort { $0.point.x < $1.point.x }
            }
            
            // 3. Connect adjacent vertices in the sorted list if not already connected.
            for i in 0..<(verticesOnPath.count - 1) {
                let v1ID = verticesOnPath[i].id
                let v2ID = verticesOnPath[i+1].id
                
                // Check if an edge already exists to avoid duplicates.
                let isAlreadyConnected = adjacency[v1ID]?.contains(where: { edgeID in
                    guard let edge = edges[edgeID] else { return false }
                    return edge.start == v2ID || edge.end == v2ID
                }) ?? false
                
                if !isAlreadyConnected {
                    addEdge(from: v1ID, to: v2ID)
                }
            }

            // 4. After connecting, run cleanup on all involved vertices
            //    to handle merging with the rest of the graph.
            for vertex in verticesOnPath {
                cleanupCollinearSegments(at: vertex.id)
            }
            return
        }
        
        // Otherwise, create a corner vertex and two edges for an L-shaped connection.
        let cornerPoint: CGPoint
        switch strategy {
        case .horizontalThenVertical:
            cornerPoint = CGPoint(x: to.x, y: from.y)
        case .verticalThenHorizontal:
            cornerPoint = CGPoint(x: from.x, y: to.y)
        }
        
        // Find or create the vertex at the corner.
        let cornerVertex: ConnectionVertex
        if let existingVertex = findVertex(at: cornerPoint) {
            cornerVertex = existingVertex
        } else {
            cornerVertex = addVertex(at: cornerPoint)
        }
        
        addEdge(from: startID, to: cornerVertex.id)
        addEdge(from: cornerVertex.id, to: endID)
        
        // After connecting, the affected points are candidates for merging.
        cleanupCollinearSegments(at: startID)
        cleanupCollinearSegments(at: cornerVertex.id)
        cleanupCollinearSegments(at: endID)
    }

    // MARK: - Graph Cleanup
    
    private func getCollinearNeighbors(for centerVertex: ConnectionVertex) -> (horizontal: [ConnectionVertex], vertical: [ConnectionVertex]) {
        guard let connectedEdgeIDs = adjacency[centerVertex.id] else { return ([], []) }

        let neighborVertices = connectedEdgeIDs.compactMap { edgeID -> ConnectionVertex? in
            guard let edge = edges[edgeID] else { return nil }
            let neighborID = edge.start == centerVertex.id ? edge.end : edge.start
            return vertices[neighborID]
        }

        var horizontalNeighbors: [ConnectionVertex] = []
        var verticalNeighbors: [ConnectionVertex] = []
        
        let tolerance: CGFloat = 1e-6
        for neighbor in neighborVertices {
            if abs(neighbor.point.y - centerVertex.point.y) < tolerance {
                horizontalNeighbors.append(neighbor)
            } else if abs(neighbor.point.x - centerVertex.point.x) < tolerance {
                verticalNeighbors.append(neighbor)
            }
        }
        return (horizontalNeighbors, verticalNeighbors)
    }

    /// Analyzes and merges collinear segments meeting at a given vertex.
    /// This method is the core of the edge merging logic.
    private func cleanupCollinearSegments(at vertexID: ConnectionVertex.ID) {
        // A vertex might be cleaned up by a previous pass, so ensure it still exists.
        guard let centerVertex = vertices[vertexID] else { return }

        // Process both horizontal and vertical axes for potential merges.
        processCollinearRun(for: centerVertex, isHorizontal: true)
        
        // The center vertex might have been removed by the horizontal pass.
        guard vertices[vertexID] != nil else { return }
        processCollinearRun(for: centerVertex, isHorizontal: false)
    }
    
    /// Traverses the entire straight-line run of vertices from a starting point,
    /// determines which can be simplified, and rewires the graph.
    private func processCollinearRun(for startVertex: ConnectionVertex, isHorizontal: Bool) {
        // 1. Discover the entire run of collinear vertices using graph traversal.
        var runVertices: [ConnectionVertex] = []
        var queue: [ConnectionVertex] = [startVertex]
        var visitedIDs: Set<ConnectionVertex.ID> = [startVertex.id]

        while let currentVertex = queue.popLast() {
            runVertices.append(currentVertex)
            
            let (h, v) = getCollinearNeighbors(for: currentVertex)
            let neighborsOnAxis = isHorizontal ? h : v
            
            for neighbor in neighborsOnAxis {
                if !visitedIDs.contains(neighbor.id) {
                    visitedIDs.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }

        // A "run" must have more than 2 vertices to be simplified (e.g., A-B-C -> A-C).
        guard runVertices.count > 2 else { return }

        // 2. Sort the run by position
        if isHorizontal {
            runVertices.sort { $0.point.x < $1.point.x }
        } else {
            runVertices.sort { $0.point.y < $1.point.y }
        }

        // 3. Identify which vertices to keep: endpoints and junctions.
        var keptVertices: [ConnectionVertex] = []
        keptVertices.append(runVertices.first!) // Always keep the start of the run
        
        let internalVertices = runVertices.dropFirst().dropLast()
        for vertex in internalVertices {
            let (h, v) = getCollinearNeighbors(for: vertex)
            let collinearDegree = isHorizontal ? h.count : v.count
            let totalDegree = adjacency[vertex.id]?.count ?? 0

            // A vertex is a junction if it has more connections than those that
            // simply place it along the collinear run. This preserves T-junctions, etc.
            if totalDegree > collinearDegree {
                keptVertices.append(vertex)
            }
        }
        keptVertices.append(runVertices.last!) // Always keep the end of the run
        
        // Ensure keptVertices is unique and sorted
        let uniqueKeptVertices = Array(Set(keptVertices))
        let sortedKeptVertices: [ConnectionVertex]
        if isHorizontal {
            sortedKeptVertices = uniqueKeptVertices.sorted { $0.point.x < $1.point.x }
        } else {
            sortedKeptVertices = uniqueKeptVertices.sorted { $0.point.y < $1.point.y }
        }
        
        // If no vertices were simplified away, there's nothing more to do.
        if sortedKeptVertices.count == runVertices.count { return }
        
        // 4. Rewire the graph.
        let runIDs = Set(runVertices.map { $0.id })
        
        // 4a. Remove all old edges that connect vertices within the original run.
        for vertex in runVertices {
            if let edgeIDs = adjacency[vertex.id] {
                for edgeID in Array(edgeIDs) {
                    if let edge = edges[edgeID] {
                        let neighborID = edge.start == vertex.id ? edge.end : edge.start
                        if runIDs.contains(neighborID) {
                            removeEdge(id: edgeID)
                        }
                    }
                }
            }
        }
        
        // 4b. Remove the intermediate vertices that were deemed unnecessary.
        let keptIDs = Set(sortedKeptVertices.map { $0.id })
        let verticesToRemove = runVertices.filter { !keptIDs.contains($0.id) }
        for vertex in verticesToRemove {
            removeVertex(id: vertex.id)
        }

        // 4c. Create new edges to connect the remaining "kept" vertices in sequence.
        for i in 0..<(sortedKeptVertices.count - 1) {
            addEdge(from: sortedKeptVertices[i].id, to: sortedKeptVertices[i+1].id)
        }
    }
    
    /// Splits an existing edge by inserting a new vertex at a specific point.
    /// - Parameters:
    ///   - edgeID: The ID of the edge to split.
    ///   - point: The location on the edge where the new vertex should be inserted.
    /// - Returns: The ID of the newly created vertex, or `nil` if the edge doesn't exist.
    @discardableResult
    func splitEdgeAndInsertVertex(edgeID: UUID, at point: CGPoint) -> ConnectionVertex.ID? {
        guard let edgeToSplit = edges[edgeID] else {
            assertionFailure("Attempted to split a non-existent edge.")
            return nil
        }
        
        let startID = edgeToSplit.start
        let endID = edgeToSplit.end
        
        // 1. Remove the old edge
        removeEdge(id: edgeID)
        
        // 2. Create the new vertex (the junction)
        let newVertex = addVertex(at: point)
        
        // 3. Create two new edges connecting the original vertices to the new one.
        addEdge(from: startID, to: newVertex.id)
        addEdge(from: newVertex.id, to: endID)
        
        return newVertex.id
    }
    
    /// Removes a vertex and any edges connected to it from the graph.
    func removeVertex(id: ConnectionVertex.ID) {
        // First, remove all edges connected to this vertex.
        if let connectedEdgeIDs = adjacency[id] {
            // Make a copy, as removing edges will mutate the set.
            for edgeID in Array(connectedEdgeIDs) {
                removeEdge(id: edgeID)
            }
        }
        
        // Then, remove the vertex itself.
        vertices.removeValue(forKey: id)
        adjacency.removeValue(forKey: id)
    }
    
    /// Removes an edge from the graph.
    func removeEdge(id: ConnectionEdge.ID) {
        guard let edge = edges.removeValue(forKey: id) else {
            // Edge already removed, do nothing.
            return
        }
        
        // Remove the edge from the adjacency lists of its start and end vertices.
        adjacency[edge.start]?.remove(id)
        adjacency[edge.end]?.remove(id)
    }
    
    /// Removes all vertices and edges from the graph.
    func clear() {
        vertices.removeAll()
        edges.removeAll()
        adjacency.removeAll()
    }
    
    /// Deletes a set of items (vertices or edges) from the graph.
    /// After deletion, it cleans up any vertices that may have become orphaned or redundant.
    func delete(items: Set<UUID>) {
        var verticesToCheck: Set<ConnectionVertex.ID> = []

        // 1. Process Edges for Deletion
        for itemID in items {
            if let edge = edges[itemID] {
                verticesToCheck.insert(edge.start)
                verticesToCheck.insert(edge.end)
                removeEdge(id: itemID)
            }
        }
        
        // 2. Process Vertices for Deletion
        for itemID in items {
            if let vertexToRemove = vertices[itemID] {
                // Add neighbors to the check list before removing the vertex
                let (horizontalNeighbors, verticalNeighbors) = getCollinearNeighbors(for: vertexToRemove)
                for neighbor in horizontalNeighbors { verticesToCheck.insert(neighbor.id) }
                for neighbor in verticalNeighbors { verticesToCheck.insert(neighbor.id) }
                
                removeVertex(id: itemID)
            }
        }

        // 3. Post-Deletion Cleanup
        for vertexID in verticesToCheck {
            // Ensure vertex still exists, as a prior cleanup might have removed it
            if vertices[vertexID] == nil { continue }

            if let adj = adjacency[vertexID], adj.isEmpty {
                // Remove orphaned vertices
                removeVertex(id: vertexID)
            } else {
                // Attempt to merge collinear segments on any non-orphaned vertex
                cleanupCollinearSegments(at: vertexID)
            }
        }
    }
    
    // MARK: - Graph Analysis
    
    /// Finds a vertex at the given point, within a small tolerance.
    private func findVertex(at point: CGPoint) -> ConnectionVertex? {
        let tolerance: CGFloat = 1e-6
        return vertices.values.first { v in
            abs(v.point.x - point.x) < tolerance && abs(v.point.y - point.y) < tolerance
        }
    }
    
    /// Finds the first edge that contains the given point.
    /// - Parameter point: The point to test for.
    /// - Returns: A `ConnectionEdge` if one is found at the point, otherwise `nil`.
    func findEdge(at point: CGPoint) -> ConnectionEdge? {
        for edge in edges.values {
            guard let startVertex = vertices[edge.start], let endVertex = vertices[edge.end] else {
                continue
            }
            if isPoint(point, onSegmentBetween: startVertex.point, p2: endVertex.point) {
                return edge
            }
        }
        return nil
    }
    
    /// Checks if a point lies on the line segment between two other points, for orthogonal lines.
    private func isPoint(_ p: CGPoint, onSegmentBetween p1: CGPoint, p2: CGPoint) -> Bool {
        let tolerance: CGFloat = 1e-6

        let minX = min(p1.x, p2.x) - tolerance
        let maxX = max(p1.x, p2.x) + tolerance
        let minY = min(p1.y, p2.y) - tolerance
        let maxY = max(p1.y, p2.y) + tolerance

        // Check if point is within the bounding box of the segment.
        guard p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY else {
            return false
        }

        // Check for collinearity for horizontal or vertical lines.
        let isHorizontal = abs(p1.y - p2.y) < tolerance
        let isVertical = abs(p1.x - p2.x) < tolerance

        if isHorizontal {
            return abs(p.y - p1.y) < tolerance
        } else if isVertical {
            return abs(p.x - p1.x) < tolerance
        }
        return false
    }
    
    /// Finds all vertices and edges belonging to the same connected net as the starting vertex.
    /// - Parameter startVertexID: The ID of the vertex where the search begins.
    /// - Returns: A tuple containing a set of all vertex IDs and a set of all edge IDs in the net.
    func net(startingFrom startVertexID: ConnectionVertex.ID) -> (vertices: Set<ConnectionVertex.ID>, edges: Set<ConnectionEdge.ID>) {
        var visitedVertices: Set<ConnectionVertex.ID> = []
        var visitedEdges: Set<ConnectionEdge.ID> = []
        var queue: [ConnectionVertex.ID] = [startVertexID]

        guard vertices[startVertexID] != nil else {
            return (visitedVertices, visitedEdges)
        }

        visitedVertices.insert(startVertexID)

        while let currentVertexID = queue.popLast() {
            // Get all edges connected to the current vertex.
            guard let connectedEdgeIDs = adjacency[currentVertexID] else { continue }
            
            for edgeID in connectedEdgeIDs {
                // If we've already processed this edge, skip it.
                if visitedEdges.contains(edgeID) { continue }
                
                visitedEdges.insert(edgeID)
                
                guard let edge = edges[edgeID] else { continue }
                
                // Find the other vertex connected by this edge.
                let otherVertexID = (edge.start == currentVertexID) ? edge.end : edge.start
                
                // If we haven't visited the other vertex yet, add it to the queue to process.
                if !visitedVertices.contains(otherVertexID) {
                    visitedVertices.insert(otherVertexID)
                    queue.append(otherVertexID)
                }
            }
        }
        
        return (visitedVertices, visitedEdges)
    }
    
    /// Finds all disconnected sub-graphs (nets) within the schematic.
    /// - Returns: An array of `Net` objects, each representing a disconnected net.
    func findNets() -> [Net] {
        var foundNets: [Net] = []
        var unvisitedVertices = Set(vertices.keys)

        while let startVertexID = unvisitedVertices.first {
            let (netVertices, netEdges) = net(startingFrom: startVertexID)
            
            // A standalone vertex is not a "segment". We only care about nets with edges.
            if !netEdges.isEmpty {
                let newNet = Net(vertexCount: netVertices.count, edgeCount: netEdges.count)
                foundNets.append(newNet)
            }
            
            unvisitedVertices.subtract(netVertices)
        }
        
        return foundNets
    }
}
