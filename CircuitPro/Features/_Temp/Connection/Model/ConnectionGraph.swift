import Foundation
import CoreGraphics

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

    public func neighbors(of vertexID: ConnectionVertex.ID) -> [ConnectionVertex.ID] {
        guard let edgeIDs = adjacency[vertexID] else { return [] }
        return edgeIDs.compactMap { edgeID in
            guard let edge = edges[edgeID] else { return nil }
            return (edge.start == vertexID) ? edge.end : edge.start
        }
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
                adjacency[otherVertex.id] = []
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

    /// Finds all vertices that are part of a continuous straight line (horizontal or vertical)
    /// connected to a given starting vertex.
    public func findCollinearVertices(startingFrom startVertexID: ConnectionVertex.ID, axis: LineOrientation) -> [ConnectionVertex] {
        guard let startVertex = vertices[startVertexID] else { return [] }

        var collinearVertices: [ConnectionVertex] = []
        var queue: [ConnectionVertex] = [startVertex]
        var visitedInSearch: Set<ConnectionVertex.ID> = [startVertex.id]

        var head = 0
        while head < queue.count {
            let currentVertex = queue[head]
            head += 1
            collinearVertices.append(currentVertex)

            guard let connectedEdgeIDs = adjacency[currentVertex.id] else { continue }

            for edgeID in connectedEdgeIDs {
                guard let edge = edges[edgeID] else { continue }
                let neighborID = (edge.start == currentVertex.id) ? edge.end : edge.start

                if visitedInSearch.contains(neighborID) { continue }
                guard let neighbor = vertices[neighborID] else { continue }

                // Check if neighbor is on the same axis relative to the current vertex
                let isCollinear: Bool
                if axis == .horizontal {
                    isCollinear = abs(neighbor.point.y - currentVertex.point.y) < 0.01
                } else { // Vertical
                    isCollinear = abs(neighbor.point.x - currentVertex.point.x) < 0.01
                }

                if isCollinear {
                    visitedInSearch.insert(neighborID)
                    queue.append(neighbor)
                }
            }
        }
        return collinearVertices
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

    public func vertex(at point: CGPoint, tolerance: CGFloat = 0.01) -> ConnectionVertex? {
        vertices.values.first { v in
            hypot(v.point.x - point.x, v.point.y - point.y) <= tolerance
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

    /// Determines the orientation of the most recent segment in the graph.
    /// This is useful for determining user intent when merging connections.
    public func lastSegmentOrientation() -> LineOrientation? {
        // This is a simplified heuristic. A more robust solution might involve
        // tracking the actual last added edge. For now, we find an endpoint
        // and check the orientation of the segment attached to it.
        guard let endpointVertexID = adjacency.first(where: { $0.value.count == 1 })?.key else {
            return nil // No endpoint found, might be a closed loop or empty graph
        }
        return lastSegmentOrientation(before: endpointVertexID)
    }

    public func isGeometricallyClose(to other: ConnectionGraph, tolerance: CGFloat = 0.01) -> Bool {
        for vNew in self.vertices.values {
            // Check against other's vertices
            for vOld in other.vertices.values {
                if abs(vNew.point.x - vOld.point.x) <= tolerance && abs(vNew.point.y - vOld.point.y) <= tolerance {
                    return true
                }
            }
            // Check against other's edges
            let hitResult = other.hitTest(at: vNew.point, tolerance: tolerance)
            if case .edge = hitResult {
                return true
            }
        }
        return false
    }

    public func hitTest(at point: CGPoint, tolerance: CGFloat) -> GraphHitResult {
        // Vertex check
        for vertex in vertices.values {
            if hypot(point.x - vertex.point.x, point.y - vertex.point.y) <= tolerance {
                if let vertexType = vertexType(for: vertex.id) {
                    return .vertex(id: vertex.id, position: vertex.point, type: vertexType)
                }
            }
        }

        // Edge check
        for (edgeID, edge) in edges {
            guard let start = vertices[edge.start]?.point,
                  let end = vertices[edge.end]?.point else { continue }
            
            let minX = min(start.x, end.x) - tolerance
            let maxX = max(start.x, end.x) + tolerance
            let minY = min(start.y, end.y) - tolerance
            let maxY = max(start.y, end.y) + tolerance

            guard point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY else {
                continue
            }

            let isVertical = abs(start.x - end.x) < tolerance
            let isHorizontal = abs(start.y - end.y) < tolerance

            if isVertical {
                if abs(point.x - start.x) < tolerance {
                    return .edge(id: edgeID, point: CGPoint(x: start.x, y: point.y), orientation: .vertical)
                }
            } else if isHorizontal {
                if abs(point.y - start.y) < tolerance {
                    return .edge(id: edgeID, point: CGPoint(x: point.x, y: start.y), orientation: .horizontal)
                }
            }
        }

        return .emptySpace
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
    
    /// Simplifies the graph by merging collinear segments, correctly handling T-junctions and complex overlaps.
    public func simplifyCollinearSegments() {
        while true {
            var wasSimplified = false
            var visitedVertices: Set<ConnectionVertex.ID> = []

            // Iterate over a copy of IDs, as we will be modifying the dictionaries
            for vertexID in vertices.keys {
                if visitedVertices.contains(vertexID) {
                    continue
                }
                guard let vertex = vertices[vertexID] else { continue }

                // For the current vertex, check for collinear segments along both axes
                for axis in [LineOrientation.horizontal, .vertical] {

                    // 1. Find all connected collinear vertices along the current axis using a traversal.
                    var collinearVertices: [ConnectionVertex] = []
                    var queue: [ConnectionVertex] = [vertex]
                    var visitedInSearch: Set<ConnectionVertex.ID> = [vertex.id]

                    var head = 0
                    while head < queue.count {
                        let currentVertex = queue[head]
                        head += 1
                        collinearVertices.append(currentVertex)

                        guard let connectedEdgeIDs = adjacency[currentVertex.id] else { continue }

                        for edgeID in connectedEdgeIDs {
                            guard let edge = edges[edgeID] else { continue }
                            let neighborID = (edge.start == currentVertex.id) ? edge.end : edge.start

                            if visitedInSearch.contains(neighborID) { continue }
                            guard let neighbor = vertices[neighborID] else { continue }

                            // Check if neighbor is on the same axis relative to the current vertex
                            let isCollinear: Bool
                            if axis == .horizontal {
                                isCollinear = abs(neighbor.point.y - currentVertex.point.y) < 0.01
                            } else { // Vertical
                                isCollinear = abs(neighbor.point.x - currentVertex.point.x) < 0.01
                            }

                            if isCollinear {
                                visitedInSearch.insert(neighborID)
                                queue.append(neighbor)
                            }
                        }
                    }

                    // We need at least 3 vertices to have an intermediate point to remove.
                    if collinearVertices.count < 3 {
                        continue
                    }

                    // Mark all found vertices as visited for the outer loop to avoid redundant checks.
                    visitedVertices.formUnion(collinearVertices.map { $0.id })

                    // 2. Identify which of these vertices are junctions (have perpendicular attachments).
                    var junctionVertices: [ConnectionVertex] = []
                    for v_collinear in collinearVertices {
                        guard let v_edges = adjacency[v_collinear.id] else { continue }
                        for edge_id in v_edges {
                            guard let edge = edges[edge_id] else { continue }
                            let neighbor_id = (edge.start == v_collinear.id) ? edge.end : edge.start
                            // If the neighbor is NOT part of the current collinear set, it's a perpendicular junction.
                            if !collinearVertices.contains(where: { $0.id == neighbor_id }) {
                                junctionVertices.append(v_collinear)
                                break
                            }
                        }
                    }

                    // 3. Find the endpoints of the entire collinear segment.
                    let endpoints: (ConnectionVertex, ConnectionVertex)
                    if axis == .horizontal {
                        guard let minX = collinearVertices.map({ $0.point.x }).min(), let maxX = collinearVertices.map({ $0.point.x }).max(), minX != maxX,
                              let p1 = collinearVertices.first(where: { $0.point.x == minX }),
                              let p2 = collinearVertices.first(where: { $0.point.x == maxX }) else { continue }
                        endpoints = (p1, p2)
                    } else { // Vertical
                        guard let minY = collinearVertices.map({ $0.point.y }).min(), let maxY = collinearVertices.map({ $0.point.y }).max(), minY != maxY,
                              let p1 = collinearVertices.first(where: { $0.point.y == minY }),
                              let p2 = collinearVertices.first(where: { $0.point.y == maxY }) else { continue }
                        endpoints = (p1, p2)
                    }

                    // 4. Determine which vertices to keep and if simplification is possible.
                    var verticesToKeep = junctionVertices
                    verticesToKeep.append(endpoints.0)
                    verticesToKeep.append(endpoints.1)
                    let uniqueKeptIDs = Set(verticesToKeep.map { $0.id })

                    if uniqueKeptIDs.count >= collinearVertices.count {
                        continue // No intermediate vertices to remove.
                    }

                    // 5. Perform the simplification.
                    // Remove all edges that are internal to the collinear set.
                    var edgesToRemove: [ConnectionEdge.ID] = []
                    for v_collinear in collinearVertices {
                        if let connectedEdgeIDs = adjacency[v_collinear.id] {
                            for edgeID in connectedEdgeIDs {
                                guard let edge = edges[edgeID] else { continue }
                                let neighborID = (edge.start == v_collinear.id) ? edge.end : edge.start
                                if collinearVertices.contains(where: { $0.id == neighborID }) {
                                    edgesToRemove.append(edgeID)
                                }
                            }
                        }
                    }
                    for edgeID in Set(edgesToRemove) {
                        if let edge = edges.removeValue(forKey: edgeID) {
                            adjacency[edge.start]?.remove(edgeID)
                            adjacency[edge.end]?.remove(edgeID)
                        }
                    }

                    // Remove intermediate vertices that are not endpoints or junctions.
                    for v_collinear in collinearVertices {
                        if !uniqueKeptIDs.contains(v_collinear.id) {
                            vertices.removeValue(forKey: v_collinear.id)
                            adjacency.removeValue(forKey: v_collinear.id)
                        }
                    }

                    // Sort the kept vertices and create new edges to connect them in a line.
                    let sortedKeptVertices = Array(uniqueKeptIDs).compactMap({ vertices[$0] }).sorted(by: {
                        axis == .horizontal ? $0.point.x < $1.point.x : $0.point.y < $1.point.y
                    })

                    for i in 0..<(sortedKeptVertices.count - 1) {
                        addUniqueEdge(from: sortedKeptVertices[i].id, to: sortedKeptVertices[i+1].id)
                    }

                    wasSimplified = true
                    break // Restart the main simplification loop
                }
                if wasSimplified { break }
            }

            if !wasSimplified {
                break // Exit while loop if no simplifications were made in a full pass
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