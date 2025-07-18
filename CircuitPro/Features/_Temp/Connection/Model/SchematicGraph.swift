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

        // If the line is already straight, just add a single edge.
        if from.x == to.x || from.y == to.y {
            addEdge(from: startID, to: endID)
            return
        }
        
        // Otherwise, create a corner vertex and two edges.
        let cornerPoint: CGPoint
        switch strategy {
        case .horizontalThenVertical:
            cornerPoint = CGPoint(x: to.x, y: from.y)
        case .verticalThenHorizontal:
            cornerPoint = CGPoint(x: from.x, y: to.y)
        }
        
        let cornerVertex = addVertex(at: cornerPoint)
        addEdge(from: startID, to: cornerVertex.id)
        addEdge(from: cornerVertex.id, to: endID)
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
    
    // MARK: - Graph Analysis
    
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
