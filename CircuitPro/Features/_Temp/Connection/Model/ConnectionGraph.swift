import Foundation
import CoreGraphics

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
    
    
    private func rebuildAdjacency() {
        adjacency = [:]
        for (edgeID, edge) in edges {
            adjacency[edge.start, default: []].insert(edgeID)
            adjacency[edge.end, default: []].insert(edgeID)
        }
    }

    
    /// Merges another graph into this one.
    /// Vertex uniqueness is determined by their ID.
    public func merge(with other: ConnectionGraph) {
        var remappedVertexIDs: [ConnectionVertex.ID: ConnectionVertex.ID] = [:]
        
        // First, process vertices from the other graph
        other.vertices.values.forEach { otherVertex in
            // Check if a vertex with the same point already exists in self
            if let existingVertex = vertices.values.first(where: { $0.point == otherVertex.point }) {
                // If a vertex with the same point exists, map the otherVertex.id to the existingVertex.id
                remappedVertexIDs[otherVertex.id] = existingVertex.id
            } else {
                // If no vertex with the same point exists, add the otherVertex to self
                vertices[otherVertex.id] = otherVertex
                adjacency[otherVertex.id] = other.adjacency[otherVertex.id] ?? []
                remappedVertexIDs[otherVertex.id] = otherVertex.id // Map to itself
            }
        }
        
        // Then, process edges from the other graph, using the remapped vertex IDs
        other.edges.values.forEach { otherEdge in
            guard let remappedStartID = remappedVertexIDs[otherEdge.start],
                  let remappedEndID = remappedVertexIDs[otherEdge.end] else {
                assertionFailure("Failed to remap vertex IDs during merge.")
                return
            }
            
            // Only add the edge if it doesn't already exist and its endpoints are valid
            // (i.e., not creating a self-loop if the remapped IDs are the same)
            if remappedStartID != remappedEndID && !edges.values.contains(where: {
                ($0.start == remappedStartID && $0.end == remappedEndID) ||
                ($0.start == remappedEndID && $0.end == remappedStartID)
            }) {
                let newEdge = ConnectionEdge(start: remappedStartID, end: remappedEndID)
                edges[newEdge.id] = newEdge
                adjacency[remappedStartID, default: []].insert(newEdge.id)
                adjacency[remappedEndID, default: []].insert(newEdge.id)
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

    // MARK: – Vertex helpers

    /// Ensures there is a vertex at the specified point (within the given tolerance).
    ///
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

    /// Splits the specified edge by inserting a vertex at `point`.
    ///
    /// If the point coincides (within tolerance) with either endpoint, the graph is left unmodified and that endpoint
    /// is returned.  Otherwise the edge is removed and two new edges are created, effectively forming a junction.
    ///
    /// The function is idempotent – repeated calls with the same parameters will not create duplicate edges.
    @discardableResult
    public func splitEdge(_ edgeID: ConnectionEdge.ID, at point: CGPoint, tolerance: CGFloat = 0.01) -> ConnectionVertex? {
        guard let edge = edges[edgeID],
              let startVertex = vertices[edge.start],
              let endVertex   = vertices[edge.end] else { return nil }

        // If point is on either endpoint, nothing to do.
        let onStart = abs(startVertex.point.x - point.x) <= tolerance && abs(startVertex.point.y - point.y) <= tolerance
        let onEnd   = abs(endVertex.point.x   - point.x) <= tolerance && abs(endVertex.point.y   - point.y) <= tolerance

        if onStart { return startVertex }
        if onEnd   { return endVertex }

        // Ensure vertex exists (will create if required)
        let junction = ensureVertex(at: point, tolerance: tolerance)

        // Remove the original edge (if still present – idempotency)
        if edges.removeValue(forKey: edgeID) != nil {
            adjacency[edge.start]?.remove(edgeID)
            adjacency[edge.end]?.remove(edgeID)
        }

        // Add the two replacement edges if they don't already exist.
        func addUniqueEdge(from a: ConnectionVertex.ID, to b: ConnectionVertex.ID) {
            // Guard against existing identical edge (in either direction)
            if !edges.values.contains(where: { ($0.start == a && $0.end == b) || ($0.start == b && $0.end == a) }) {
                _ = addEdge(from: a, to: b)
            }
        }

        addUniqueEdge(from: startVertex.id, to: junction.id)
        addUniqueEdge(from: junction.id, to: endVertex.id)

        return junction
    }
    
    /// Simplifies the graph by merging collinear segments.
    public func simplifyCollinearSegments() {
        while true {
            var didSimplify = false
            let vertexIDs = Array(vertices.keys)

            for vertexID in vertexIDs {
                guard let vertex = vertices[vertexID] else { continue }
                guard let connectedEdgeIDs = adjacency[vertexID], connectedEdgeIDs.count >= 2 else { continue }

                let connectedEdges = connectedEdgeIDs.compactMap { edges[$0] }
                if connectedEdges.count != connectedEdgeIDs.count {
                    rebuildAdjacency()
                    didSimplify = true
                    break
                }

                var horizontalNeighbors: [ConnectionVertex.ID: ConnectionVertex] = [:]
                var verticalNeighbors: [ConnectionVertex.ID: ConnectionVertex] = [:]
                var allNeighbors: [ConnectionVertex.ID: ConnectionVertex] = [:]

                for edge in connectedEdges {
                    let neighborID = (edge.start == vertex.id) ? edge.end : edge.start
                    guard let neighbor = vertices[neighborID] else { continue }
                    allNeighbors[neighborID] = neighbor
                    if abs(neighbor.point.y - vertex.point.y) < 0.01 { horizontalNeighbors[neighborID] = neighbor }
                    if abs(neighbor.point.x - vertex.point.x) < 0.01 { verticalNeighbors[neighborID] = neighbor }
                }

                if horizontalNeighbors.count >= 2 && horizontalNeighbors.count == allNeighbors.count {
                    let allLineVertices = Array(horizontalNeighbors.values) + [vertex]
                    let points = allLineVertices.map { $0.point }
                    guard let minX = points.map({ $0.x }).min(), let maxX = points.map({ $0.x }).max(), minX != maxX else { continue }

                    guard let leftEnd = allLineVertices.first(where: { $0.point.x == minX }),
                          let rightEnd = allLineVertices.first(where: { $0.point.x == maxX }) else { continue }

                    let toRemove = allLineVertices.filter { $0.id != leftEnd.id && $0.id != rightEnd.id }
                    for v in toRemove {
                        if let edgesToRemove = adjacency[v.id] {
                            for edgeID in edgesToRemove {
                                if let edge = edges.removeValue(forKey: edgeID) {
                                    let neighborID = (edge.start == v.id) ? edge.end : edge.start
                                    adjacency[neighborID]?.remove(edgeID)
                                }
                            }
                        }
                        vertices.removeValue(forKey: v.id)
                        adjacency.removeValue(forKey: v.id)
                    }

                    addUniqueEdge(from: leftEnd.id, to: rightEnd.id)
                    didSimplify = true
                    break
                }

                if verticalNeighbors.count >= 2 && verticalNeighbors.count == allNeighbors.count {
                    let allLineVertices = Array(verticalNeighbors.values) + [vertex]
                    let points = allLineVertices.map { $0.point }
                    guard let minY = points.map({ $0.y }).min(), let maxY = points.map({ $0.y }).max(), minY != maxY else { continue }

                    guard let bottomEnd = allLineVertices.first(where: { $0.point.y == minY }),
                          let topEnd = allLineVertices.first(where: { $0.point.y == maxY }) else { continue }

                    let toRemove = allLineVertices.filter { $0.id != bottomEnd.id && $0.id != topEnd.id }
                    for v in toRemove {
                        if let edgesToRemove = adjacency[v.id] {
                            for edgeID in edgesToRemove {
                                if let edge = edges.removeValue(forKey: edgeID) {
                                    let neighborID = (edge.start == v.id) ? edge.end : edge.start
                                    adjacency[neighborID]?.remove(edgeID)
                                }
                            }
                        }
                        vertices.removeValue(forKey: v.id)
                        adjacency.removeValue(forKey: v.id)
                    }

                    addUniqueEdge(from: bottomEnd.id, to: topEnd.id)
                    didSimplify = true
                    break
                }
            }

            if !didSimplify {
                break
            }
        }
    }

    private func addUniqueEdge(from a: ConnectionVertex.ID, to b: ConnectionVertex.ID) {
        guard a != b else { return }
        if !edges.values.contains(where: { ($0.start == a && $0.end == b) || ($0.start == b && $0.end == a) }) {
            _ = addEdge(from: a, to: b)
        }
    }
    
    public func removeEdges(withIDs edgeIDsToRemove: Set<ConnectionEdge.ID>) -> [ConnectionGraph] {
        // 1. Create a new graph state with the specified edges removed.
        var remainingEdges = self.edges
        edgeIDsToRemove.forEach { remainingEdges.removeValue(forKey: $0) }

        if remainingEdges.isEmpty {
            return []
        }

        // 2. Determine the set of vertices that are still part of the graph.
        let activeVertexIDs = Set(remainingEdges.values.flatMap { [$0.start, $0.end] })

        // 3. Find all connected components in the remaining graph.
        var visitedVertices: Set<ConnectionVertex.ID> = []
        var components: [ConnectionGraph] = []

        for vertexID in activeVertexIDs {
            if !visitedVertices.contains(vertexID) {
                // This vertex is part of an unvisited component. Start a traversal.
                var componentVertices: [ConnectionVertex.ID: ConnectionVertex] = [:]
                var componentEdges: [ConnectionEdge.ID: ConnectionEdge] = [:]
                var queue: [ConnectionVertex.ID] = [vertexID]
                visitedVertices.insert(vertexID)

                var head = 0
                while head < queue.count {
                    let currentVertexID = queue[head]
                    head += 1

                    if let vertex = self.vertices[currentVertexID] {
                        componentVertices[currentVertexID] = vertex
                    }

                    // Find all connected edges from the original graph that are still in remainingEdges.
                    if let originalConnectedEdgeIDs = self.adjacency[currentVertexID] {
                        for edgeID in originalConnectedEdgeIDs {
                            if let edge = remainingEdges[edgeID], componentEdges[edgeID] == nil {
                                componentEdges[edgeID] = edge

                                // Add the neighbor to the queue if it hasn't been visited.
                                let neighborID = (edge.start == currentVertexID) ? edge.end : edge.start
                                if !visitedVertices.contains(neighborID) {
                                    visitedVertices.insert(neighborID)
                                    queue.append(neighborID)
                                }
                            }
                        }
                    }
                }

                // 4. Create a new ConnectionGraph for the found component.
                if !componentEdges.isEmpty {
                    let newGraph = ConnectionGraph(vertices: componentVertices, edges: componentEdges)
                    newGraph.rebuildAdjacency()
                    components.append(newGraph)
                }
            }
        }

        return components
    }
}
