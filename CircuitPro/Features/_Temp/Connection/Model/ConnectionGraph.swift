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
    
    /// Simplifies the graph by merging collinear segments.
    public func simplifyCollinearSegments() {
        var changed = true
        while changed {
            changed = false
            var verticesToRemove: Set<ConnectionVertex.ID> = []
            var edgesToAdd: [ConnectionEdge] = []
            var edgesToRemove: Set<ConnectionEdge.ID> = []

            // Iterate through vertices to find candidates for removal
            for (vertexID, vertex) in vertices {
                let connectedEdgeIDs = adjacency[vertexID] ?? []

                // A vertex is a candidate for removal if it has exactly two connected edges
                // and those edges are collinear.
                if connectedEdgeIDs.count == 2 {
                    let edgeIDsArray = Array(connectedEdgeIDs)
                    let edge1ID = edgeIDsArray[0]
                    let edge2ID = edgeIDsArray[1]

                    guard let edge1 = edges[edge1ID], let edge2 = edges[edge2ID] else { continue }

                    // Determine the other endpoints of the two edges
                    let otherVertexID1 = (edge1.start == vertexID) ? edge1.end : edge1.start
                    let otherVertexID2 = (edge2.start == vertexID) ? edge2.end : edge2.start

                    guard let otherVertex1 = vertices[otherVertexID1],
                          let otherVertex2 = vertices[otherVertexID2] else { continue }

                    // Check for collinearity of the three points: otherVertex1.point, vertex.point, otherVertex2.point
                    let p1 = otherVertex1.point
                    let p2 = vertex.point
                    let p3 = otherVertex2.point

                    let isCollinear: Bool
                    // Assuming orthogonal lines for now
                    if (p1.x == p2.x && p2.x == p3.x) || (p1.y == p2.y && p2.y == p3.y) {
                        isCollinear = true
                    } else {
                        isCollinear = false
                    }

                    if isCollinear {
                        // Mark vertex and edges for removal
                        verticesToRemove.insert(vertexID)
                        edgesToRemove.insert(edge1ID)
                        edgesToRemove.insert(edge2ID)

                        // Create a new merged edge between the two outer vertices
                        let newEdge = ConnectionEdge(start: otherVertexID1, end: otherVertexID2)
                        edgesToAdd.append(newEdge)
                        changed = true // Mark that a change occurred
                    }
                }
            }

            // Apply changes: remove old vertices and edges, add new merged edges
            for vertexID in verticesToRemove {
                vertices.removeValue(forKey: vertexID)
                adjacency.removeValue(forKey: vertexID)
            }

            for edgeID in edgesToRemove {
                edges.removeValue(forKey: edgeID)
            }

            for newEdge in edgesToAdd {
                edges[newEdge.id] = newEdge
                // Update adjacency for the new edge's endpoints
                adjacency[newEdge.start, default: []].insert(newEdge.id)
                adjacency[newEdge.end, default: []].insert(newEdge.id)
            }
            rebuildAdjacency()
        }
    }
    
    public func removeEdges(withIDs edgeIDsToRemove: Set<ConnectionEdge.ID>) -> [ConnectionGraph] {
        // 1. Create a mutable copy of the current graph's data
        var currentVertices = self.vertices
        var currentEdges = self.edges
        var currentAdjacency = self.adjacency
        
        // 2. Remove specified edges and update adjacency
        for edgeID in edgeIDsToRemove {
            if let edge = currentEdges[edgeID] {
                currentEdges.removeValue(forKey: edgeID)
                currentAdjacency[edge.start]?.remove(edgeID)
                currentAdjacency[edge.end]?.remove(edgeID)
            }
        }
        
        // 3. Remove isolated vertices (vertices with no connected edges)
        //    and identify connected components
        var visitedVertices: Set<ConnectionVertex.ID> = []
        var components: [ConnectionGraph] = []
        
        for (vertexID, _) in currentVertices {
            // Only process unvisited vertices that still have edges connected to them
            if !visitedVertices.contains(vertexID) && (currentAdjacency[vertexID]?.isEmpty == false || currentEdges.values.contains(where: { $0.start == vertexID || $0.end == vertexID })) {
                // Start a new BFS/DFS from this unvisited vertex to find a component
                var queue: [ConnectionVertex.ID] = [vertexID]
                var currentComponentVertices: [ConnectionVertex.ID: ConnectionVertex] = [:]
                var currentComponentEdges: [ConnectionEdge.ID: ConnectionEdge] = [:]
                var currentComponentAdjacency: [ConnectionVertex.ID: Set<ConnectionEdge.ID>] = [:]
                
                visitedVertices.insert(vertexID)
                currentComponentVertices[vertexID] = currentVertices[vertexID]
                
                var head = 0
                while head < queue.count {
                    let uID = queue[head]
                    head += 1
                    
                    // Add uID to current component's adjacency list if it has edges
                    if let connectedEdges = currentAdjacency[uID], !connectedEdges.isEmpty {
                        currentComponentAdjacency[uID] = Set<ConnectionEdge.ID>()
                        for edgeID in connectedEdges {
                            if let edge = currentEdges[edgeID] {
                                currentComponentEdges[edgeID] = edge
                                currentComponentAdjacency[uID]?.insert(edgeID)
                                
                                let vID = (edge.start == uID) ? edge.end : edge.start
                                
                                if !visitedVertices.contains(vID) {
                                    visitedVertices.insert(vID)
                                    currentComponentVertices[vID] = currentVertices[vID]
                                    queue.append(vID)
                                }
                            }
                        }
                    } else if currentAdjacency[uID]?.isEmpty == true && !currentEdges.values.contains(where: { $0.start == uID || $0.end == uID }) {
                        // If a vertex has no connected edges after removal, it's isolated. Don't add to component.
                        // This case is handled by the outer loop's `if !visitedVertices.contains(vertexID)`
                        // and the condition `(currentAdjacency[vertexID]?.isEmpty == false || currentEdges.values.contains(where: { $0.start == vertexID || $0.end == vertexID }))`
                    }
                }
                // Only add component if it has vertices (i.e., not an isolated vertex that was skipped)
                if !currentComponentVertices.isEmpty {
                    components.append(ConnectionGraph(vertices: currentComponentVertices, edges: currentComponentEdges, adjacency: currentComponentAdjacency))
                }
            }
        }
        return components
    }
}
