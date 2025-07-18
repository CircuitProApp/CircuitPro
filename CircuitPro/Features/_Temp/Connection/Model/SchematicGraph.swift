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