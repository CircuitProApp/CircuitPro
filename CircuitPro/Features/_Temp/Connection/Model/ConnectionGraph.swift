import Foundation
import CoreGraphics

/// Represents a vertex in the connection graph.
public struct ConnectionVertex: Identifiable, Hashable {
    public let id: UUID
    public var point: CGPoint

    public init(id: UUID = .init(), point: CGPoint) {
        self.id = id
        self.point = point
    }
}

/// Represents an edge in the connection graph, connecting two vertices.
public struct ConnectionEdge: Identifiable, Hashable {
    public let id: UUID
    public let start: ConnectionVertex.ID
    public let end: ConnectionVertex.ID

    public init(id: UUID = .init(), start: ConnectionVertex.ID, end: ConnectionVertex.ID) {
        self.id = id
        self.start = start
        self.end = end
    }
}

/// Represents a "net" as a graph of vertices and edges.
/// This class manages the topology of a connection, allowing for complex networks
/// and merging of different connection elements.
public class ConnectionGraph {
    private(set) var vertices: [ConnectionVertex.ID: ConnectionVertex]
    private(set) var edges: [ConnectionEdge.ID: ConnectionEdge]
    
    // Adjacency list for efficient graph traversal. Maps a vertex ID to a set of connected edge IDs.
    private(set) var adjacency: [ConnectionVertex.ID: Set<ConnectionEdge.ID>]

    public init(
        vertices: [ConnectionVertex.ID: ConnectionVertex] = [:],
        edges: [ConnectionEdge.ID: ConnectionEdge] = [:],
        adjacency: [ConnectionVertex.ID : Set<ConnectionEdge.ID>] = [:]
    ) {
        self.vertices = vertices
        self.edges = edges
        self.adjacency = adjacency
    }

    @discardableResult
    public func addVertex(at point: CGPoint) -> ConnectionVertex {
        let vertex = ConnectionVertex(point: point)
        vertices[vertex.id] = vertex
        adjacency[vertex.id] = []
        return vertex
    }

    @discardableResult
    public func addEdge(from startVertexID: ConnectionVertex.ID, to endVertexID: ConnectionVertex.ID) -> ConnectionEdge? {
        guard vertices[startVertexID] != nil, vertices[endVertexID] != nil else {
            assertionFailure("Attempted to create an edge with non-existent vertices.")
            return nil
        }
        let edge = ConnectionEdge(start: startVertexID, end: endVertexID)
        edges[edge.id] = edge
        adjacency[startVertexID]?.insert(edge.id)
        adjacency[endVertexID]?.insert(edge.id)
        return edge
    }

    /// Merges another graph into this one.
    /// Vertex uniqueness is determined by their ID. A more sophisticated implementation
    /// might unify vertices based on proximity.
    public func merge(with other: ConnectionGraph) {
        other.vertices.values.forEach { vertex in
            if vertices[vertex.id] == nil {
                vertices[vertex.id] = vertex
                adjacency[vertex.id] = other.adjacency[vertex.id] ?? []
            }
        }
        
        other.edges.values.forEach { edge in
            if edges[edge.id] == nil {
                edges[edge.id] = edge
                adjacency[edge.start]?.insert(edge.id)
                adjacency[edge.end]?.insert(edge.id)
            }
        }
    }

    /// Translates all vertices in the graph by a given offset.
    public func translate(by offset: CGPoint) {
        for id in vertices.keys {
            vertices[id]?.point.x += offset.x
            vertices[id]?.point.y += offset.y
        }
    }
}
