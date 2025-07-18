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
}