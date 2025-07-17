import Foundation
import CoreGraphics
import Observation

public enum GraphHitResult: Equatable {
    case emptySpace
    case vertex(id: UUID, position: CGPoint, type: VertexType)
    case edge(id: UUID, point: CGPoint, orientation: LineOrientation)
}

/// Represents a vertex in the connection graph.
public class ConnectionVertex: Identifiable {
    public let id: UUID
    public var point: CGPoint

    public init(id: UUID = .init(), point: CGPoint) {
        self.id = id
        self.point = point
    }
}

/// Represents an edge in the connection graph, connecting two vertices.
public class ConnectionEdge: Identifiable {
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
@Observable
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

    public func removeVertex(id: UUID) {
        guard let edgeIDs = adjacency[id] else {
            // If vertex has no edges, just remove it.
            vertices.removeValue(forKey: id)
            adjacency.removeValue(forKey: id)
            return
        }

        // Remove all incident edges
        for edgeID in edgeIDs {
            if let edge = edges.removeValue(forKey: edgeID) {
                // Remove edge from neighbor's adjacency list
                let neighborID = (edge.start == id) ? edge.end : edge.start
                adjacency[neighborID]?.remove(edgeID)
            }
        }

        // Remove vertex and its adjacency list
        adjacency.removeValue(forKey: id)
        vertices.removeValue(forKey: id)
    }

    // MARK: – Vertex helpers

    /// Ensures there is a vertex at the specified point (within the given tolerance).
    ///""
    /// - If a vertex already exists at that location, the existing instance is returned.
    /// - Otherwise a new vertex is inserted, added to the vertex store and returned.
    ///
    /// The adjacency list is initialised for newly-created vertices.
    @discardableResult
    public func ensureVertex(at point: CGPoint, tolerance: CGFloat = 0.01) -> ConnectionVertex {
        if let existing = vertices.values.first(where: { hypot($0.point.x - point.x, $0.point.y - point.y) <= tolerance }) {
            return existing
        }

        let v = ConnectionVertex(point: point)
        vertices[v.id] = v
        adjacency[v.id] = []
        return v
    }

    /// Determines the orientation of the last segment leading to a given vertex.
    public func lastSegmentOrientation(before vertexID: UUID) -> LineOrientation? {
        guard let lastVertex = vertices[vertexID],
              let connectedEdges = adjacency[vertexID],
              connectedEdges.count == 1,
              let edgeID = connectedEdges.first,
              let edge = edges[edgeID] else {
            return nil
        }

        let neighborID = (edge.start == vertexID) ? edge.end : edge.start
        guard let neighbor = vertices[neighborID] else {
            return nil
        }

        if abs(lastVertex.point.x - neighbor.point.x) < 0.01 {
            return .vertical
        } else {
            return .horizontal
        }
    }

    public func vertexType(for vertexID: ConnectionVertex.ID) -> VertexType? {
        guard let edgeCount = adjacency[vertexID]?.count else {
            return nil
        }

        switch edgeCount {
        case 1:
            return .endpoint
        case 2:
            return .corner
        case 3...:
            return .junction
        default: // 0
            return nil
        }
    }

    public func hitTest(at point: CGPoint, tolerance: CGFloat) -> GraphHitResult {
        // Check for vertex hits first
        for vertex in vertices.values {
            if hypot(point.x - vertex.point.x, point.y - vertex.point.y) <= tolerance {
                let type = vertexType(for: vertex.id) ?? .corner // Default for safety
                return .vertex(id: vertex.id, position: vertex.point, type: type)
            }
        }

        // Then check for edge hits
        for edge in edges.values {
            guard let start = vertices[edge.start]?.point, let end = vertices[edge.end]?.point else { continue }

            let dx = end.x - start.x
            let dy = end.y - start.y

            if dx == 0 && dy == 0 { continue }

            let t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)

            let closestPoint: CGPoint
            if t < 0 {
                closestPoint = start
            } else if t > 1 {
                closestPoint = end
            } else {
                closestPoint = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
            }

            if hypot(point.x - closestPoint.x, point.y - closestPoint.y) <= tolerance {
                let orientation: LineOrientation = (abs(start.x - end.x) < 0.01) ? .vertical : .horizontal
                return .edge(id: edge.id, point: point, orientation: orientation)
            }
        }

        return .emptySpace
    }
}
