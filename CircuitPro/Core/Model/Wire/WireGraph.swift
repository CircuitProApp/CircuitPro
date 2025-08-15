//
//  WireGraph.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/17/25.
//

//swiftlint:disable cyclomatic_complexity
//swiftlint:disable identifier_name
import Foundation
import SwiftUI

// --- Existing Enums and Structs are unchanged ---
enum VertexOwnership: Hashable {
    case free
    case pin(ownerID: UUID, pinID: UUID)
    case detachedPin // Temporarily marks a vertex that was a pin but is now being dragged
}

struct WireVertex: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
    var ownership: VertexOwnership
    var netID: UUID?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WireVertex, rhs: WireVertex) -> Bool {
        lhs.id == rhs.id
    }
}

struct WireEdge: Identifiable, Hashable {
    let id: UUID
    let start: WireVertex.ID
    let end: WireVertex.ID
}


@Observable
class WireGraph { // swiftlint:disable:this type_body_length
    // MARK: - Net Definition
    struct Net: Identifiable, Hashable, Equatable {
        let id: UUID // This is the persistent net ID
        var name: String
        let vertexCount: Int
        let edgeCount: Int
    }
    
    enum WireConnectionStrategy {
        case horizontalThenVertical
        case verticalThenHorizontal
    }
    
    // MARK: - Graph State
    private(set) var vertices: [WireVertex.ID: WireVertex] = [:]
    private(set) var edges: [WireEdge.ID: WireEdge] = [:]
    private(set) var adjacency: [WireVertex.ID: Set<WireEdge.ID>] = [:]
    private var netNames: [UUID: String] = [:]
    private var nextNetNumber = 1

    // MARK: - Drag State
    private struct DragState {
        let originalVertexPositions: [UUID: CGPoint]
        let selectedEdges: [WireEdge]
        let verticesToMove: Set<UUID>
        var newVertices: Set<UUID> = []
    }
    private var dragState: DragState?
    
    // MARK: - New Persistence API
    
    /// A callback closure that gets executed whenever the graph's topology changes,
    /// signaling that the model should be persisted.
    var onModelDidChange: (() -> Void)?
    
    /// Builds the graph from an array of persistent `Wire` objects.
    /// This method creates vertices with pin ownership at a temporary `CGPoint.zero` location.
    /// The `syncPins` method must be called afterward to move these vertices to their correct final positions.
    public func build(from wires: [Wire]) {
        guard !wires.isEmpty else { return }

        // Clear any existing graph state before building from persistent data.
        self.vertices.removeAll()
        self.edges.removeAll()
        self.adjacency.removeAll()
        self.netNames.removeAll()
        self.nextNetNumber = 1

        var attachmentMap: [AttachmentPoint: WireVertex.ID] = [:]

        // Helper to get or create a vertex for a given attachment point.
        func getVertexID(for point: AttachmentPoint, netID: UUID) -> WireVertex.ID {
            if let existingID = attachmentMap[point] {
                return existingID
            }

            let newVertex: WireVertex
            switch point {
            case .free(let pt):
                newVertex = addVertex(at: pt, ownership: .free)
            case .pin(let componentInstanceID, let pinID):
                // Create pin-owned vertices at a placeholder location. `syncPins` will position them correctly later.
                newVertex = addVertex(at: .zero, ownership: .pin(ownerID: componentInstanceID, pinID: pinID))
            }
            
            // Assign the persistent net ID to the new vertex.
            vertices[newVertex.id]?.netID = netID
            attachmentMap[point] = newVertex.id
            return newVertex.id
        }
        
        // Iterate through each persistent wire and its segments to reconstruct the graph.
        for wire in wires {
            for segment in wire.segments {
                let startID = getVertexID(for: segment.start, netID: wire.id)
                let endID = getVertexID(for: segment.end, netID: wire.id)

                if startID != endID {
                    addEdge(from: startID, to: endID)
                }
            }
        }
    }
    
    /// Converts the current in-memory graph state into an array of serializable `Wire` objects.
    public func toWires() -> [Wire] {
        var wires: [Wire] = []
        var processedVertices = Set<WireVertex.ID>()

        for vertexID in vertices.keys {
            guard !processedVertices.contains(vertexID) else { continue }

            let (netVertices, netEdges) = net(startingFrom: vertexID)
            guard !netEdges.isEmpty, let netID = vertices[vertexID]?.netID else {
                processedVertices.formUnion(netVertices)
                continue
            }

            let segments = netEdges.compactMap { edgeID -> WireSegment? in
                guard let edge = self.edges[edgeID],
                      let startVertex = self.vertices[edge.start],
                      let endVertex = self.vertices[edge.end],
                      let startPoint = attachmentPoint(for: startVertex),
                      let endPoint = attachmentPoint(for: endVertex) else { return nil }
                
                return WireSegment(start: startPoint, end: endPoint)
            }

            if !segments.isEmpty {
                wires.append(Wire(id: netID, segments: segments))
            }
            processedVertices.formUnion(netVertices)
        }
        return wires
    }

    /// Converts a `WireVertex` into its serializable `AttachmentPoint` representation.
    private func attachmentPoint(for vertex: WireVertex) -> AttachmentPoint? {
        switch vertex.ownership {
        case .free, .detachedPin: // Treat detached pins as free for persistence.
            return .free(point: vertex.point)
        case .pin(let ownerID, let pinID):
            return .pin(componentInstanceID: ownerID, pinID: pinID)
        }
    }
    
    /// Releases ownership of all pins associated with a given component instance ID.
    /// This is called when a component is deleted, turning its connected pins into free-floating vertices.
    public func releasePins(for ownerID: UUID) {
        let verticesToRelease = vertices.values.filter { vertex in
            if case .pin(let oID, _) = vertex.ownership, oID == ownerID {
                return true
            }
            return false
        }
        for var vertex in verticesToRelease {
            vertex.ownership = .free
            vertices[vertex.id] = vertex
        }
    }

    // MARK: - Public API
    /// Renames a net.
    public func setName(_ name: String, for netID: UUID) {
        netNames[netID] = name
    }
    
    /// The authoritative method for getting a vertex for a given point.
    /// It finds an existing vertex, splits an edge if the point is on one, or creates a new vertex.
    func getOrCreateVertex(at point: CGPoint) -> WireVertex.ID {
        if let existingVertex = findVertex(at: point) {
            return existingVertex.id
        }
        if let edgeToSplit = findEdge(at: point) {
            // This point is on an edge, so we must split it.
            return splitEdgeAndInsertVertex(edgeID: edgeToSplit.id, at: point)!
        }
        // The point is in empty space.
        return addVertex(at: point, ownership: .free).id
    }
    
    /// Finds a vertex for a pin, or creates one, promoting a junction if necessary.
    func getOrCreatePinVertex(at point: CGPoint, ownerID: UUID, pinID: UUID) -> WireVertex.ID {
        let ownership: VertexOwnership = .pin(ownerID: ownerID, pinID: pinID)
        if let existingVertex = findVertex(at: point) {
            // A vertex already exists here. We must claim it.
            vertices[existingVertex.id]?.ownership = ownership
            return existingVertex.id
        }
        if let edgeToSplit = findEdge(at: point) {
            // A pin is being placed on an existing wire. Split it and claim the new vertex.
            return splitEdgeAndInsertVertex(edgeID: edgeToSplit.id, at: point, ownership: ownership)!
        }
        // The pin is in empty space.
        return addVertex(at: point, ownership: ownership).id
    }
    
    /// Creates a new orthogonal wire and normalizes the graph.
    func connect(
        from startID: WireVertex.ID,
        to endID: WireVertex.ID,
        preferring strategy: WireConnectionStrategy = .horizontalThenVertical
    ) {
        guard let startVertex = vertices[startID], let endVertex = vertices[endID] else {
            assertionFailure("Cannot connect non-existent vertices.")
            return
        }

        var affectedVertices: Set<WireVertex.ID> = [startID, endID]
        let startPoint = startVertex.point
        let destinationPoint = endVertex.point

        if startPoint.x == destinationPoint.x || startPoint.y == destinationPoint.y {
            connectStraightLine(from: startVertex, to: endVertex, affectedVertices: &affectedVertices)
        } else {
            handleLShapeWire(
                from: startVertex,
                to: endVertex,
                strategy: strategy,
                affectedVertices: &affectedVertices
            )
        }

        unifyNetIDs(between: startID, and: endID)
        normalize(around: affectedVertices)
        onModelDidChange?()
    }

    /// Deletes items and normalizes the graph.
    func delete(items: Set<UUID>) {
        var verticesToCheck: Set<WireVertex.ID> = []
        for itemID in items {
            if let edge = edges[itemID] {
                verticesToCheck.insert(edge.start)
                verticesToCheck.insert(edge.end)
                removeEdge(id: itemID)
            }
        }
        for itemID in items {
            if let vertexToRemove = vertices[itemID] {
                let (horizontal, vertical) = getCollinearNeighbors(for: vertexToRemove)
                vertical.forEach { verticesToCheck.insert($0.id) }
                horizontal.forEach { verticesToCheck.insert($0.id) }
                removeVertex(id: itemID)
            }
        }
        normalize(around: verticesToCheck)
        onModelDidChange?()
    }

    /// Moves a vertex to a new point. This is a low-level operation
    /// that does not perform normalization.
    func moveVertex(id: WireVertex.ID, to newPoint: CGPoint) {
        if vertices[id]?.point != newPoint {
            vertices[id]?.point = newPoint
        }
    }

    // MARK: - Drag Lifecycle
    /// Call this when a drag gesture begins.
    /// It caches the initial state of the graph needed for calculations.
    public func beginDrag(selectedIDs: Set<UUID>) -> Bool {
        // 1. Find pins of selected SYMBOLS (via their ComponentInstance owner). These are always movable.
        let symbolPinVertexIDs = vertices.values
            .filter { vertex in
                if case .pin(let ownerID, _) = vertex.ownership {
                    return selectedIDs.contains(ownerID)
                }
                return false
            }
            .map { $0.id }

        // 2. Find vertices of selected EDGES.
        let selectedEdges = self.edges.values.filter { selectedIDs.contains($0.id) }
        
        // 3. Critically, only consider vertices from these edges that are NOT pins.
        // Pins act as anchors and should not move when only their wire is selected.
        let movableEdgeVertexIDs = selectedEdges
            .flatMap { [$0.start, $0.end] }
            .filter { vertexID in
                // Keep the vertex ID only if its ownership is anything OTHER than .pin
                guard let vertex = self.vertices[vertexID] else { return false }
                if case .pin = vertex.ownership {
                    return false // This is a pin, DO NOT move it.
                }
                return true // This is a free vertex, KEEP it.
            }

        // 4. The final set of vertices to move is the union of the two sets.
        let allMovableVertexIDs = Set(symbolPinVertexIDs).union(movableEdgeVertexIDs)
        
        guard !allMovableVertexIDs.isEmpty else {
            self.dragState = nil
            return false
        }

        self.dragState = DragState(
            originalVertexPositions: self.vertices.mapValues { $0.point },
            selectedEdges: selectedEdges,
            verticesToMove: allMovableVertexIDs
        )
        return true
    }

    /// Call this repeatedly as the user drags.
    /// It contains the complex BFS logic to update vertex positions.
    public func updateDrag(by delta: CGPoint) {
        guard var state = dragState else { return }

        // MARK: - Pre-processing
        // Detach any selected pins that are being dragged off-axis.
        for vertexID in state.verticesToMove {
            guard let vertex = vertices[vertexID], case .pin = vertex.ownership else { continue }

            let isOffAxis = (adjacency[vertexID] ?? []).contains { edgeID in
                guard let edge = state.selectedEdges.first(where: { $0.id == edgeID }),
                      let originalPos = state.originalVertexPositions[vertexID] else { return false }
                let otherEndID = edge.start == vertexID ? edge.end : edge.start
                guard let otherEndOrigPos = state.originalVertexPositions[otherEndID] else { return false }

                let wasHorizontal = abs(originalPos.y - otherEndOrigPos.y) < 1e-6
                return (wasHorizontal && abs(delta.y) > 1e-6) || (!wasHorizontal && abs(delta.x) > 1e-6)
            }

            if isOffAxis {
                let pinOwnership = vertex.ownership
                let pinPoint = vertex.point

                vertices[vertexID]?.ownership = .detachedPin

                let newStaticPinVertex = addVertex(at: pinPoint, ownership: pinOwnership)
                state.newVertices.insert(newStaticPinVertex.id)
                addEdge(from: vertexID, to: newStaticPinVertex.id)
            }
        }
        self.dragState = state

        // MARK: - Position Calculation
        var newPositions: [UUID: CGPoint] = [:]

        // Step 1: Calculate naive new positions for all moving vertices.
        for id in state.verticesToMove {
            if let origin = state.originalVertexPositions[id] {
                newPositions[id] = CGPoint(x: origin.x + delta.x, y: origin.y + delta.y)
            }
        }

        // Step 2: Correct positions for detached pins to enforce orthogonality (create L-bends).
        for vertexID in state.verticesToMove {
            guard let vertex = vertices[vertexID], vertex.ownership == .detachedPin else { continue }

            guard let staticPinNeighbor = findNeighbor(of: vertexID, where: { neighborID, _ in
                if case .pin = self.vertices[neighborID]?.ownership {
                    return newPositions[neighborID] == nil // Is a non-moving pin
                }
                return false
            }),
                  let movingNeighbor = findNeighbor(of: vertexID, where: { neighborID, edge in
                      return newPositions[neighborID] != nil && state.selectedEdges.contains(where: { $0.id == edge.id })
                  }) else { continue }
            
            let originalVertexPos = state.originalVertexPositions[vertexID]!
            let originalMovingNeighborPos = state.originalVertexPositions[movingNeighbor.id]!
            let newMovingNeighborPos = newPositions[movingNeighbor.id]!
            
            let wasHorizontal = abs(originalVertexPos.y - originalMovingNeighborPos.y) < 1e-6
            
            if wasHorizontal {
                newPositions[vertexID] = CGPoint(x: staticPinNeighbor.point.x, y: newMovingNeighborPos.y)
            } else {
                newPositions[vertexID] = CGPoint(x: newMovingNeighborPos.x, y: staticPinNeighbor.point.y)
            }
        }
        
        // Step 3: Propagate constraints via BFS to unselected parts of the circuit.
        var queue: [UUID] = Array(state.verticesToMove)
        var head = 0
        while head < queue.count {
            let junctionID = queue[head]; head += 1
            guard let junctionNewPos = newPositions[junctionID] else { continue }
            
            for edgeID in adjacency[junctionID] ?? [] {
                guard let edge = edges[edgeID] else { continue }
                let anchorID = edge.start == junctionID ? edge.end : edge.start
                
                if newPositions[anchorID] != nil { continue } // Already processed.
                
                guard let anchorOrigPos = state.originalVertexPositions[anchorID],
                      let junctionOrigPos = state.originalVertexPositions[junctionID] else { continue }
                
                let wasHorizontal = abs(anchorOrigPos.y - junctionOrigPos.y) < 1e-6
                let isOffAxisPull = (wasHorizontal && abs(junctionNewPos.y - junctionOrigPos.y) > 1e-6) ||
                (!wasHorizontal && abs(junctionNewPos.x - junctionOrigPos.x) > 1e-6)
                
                if var anchorVertex = vertices[anchorID], case .pin = anchorVertex.ownership {
                    if isOffAxisPull {
                        // This is an unselected pin being pulled off-axis. Detach it.
                        let pinOwnership = anchorVertex.ownership
                        let pinPoint = anchorVertex.point
                        
                        anchorVertex.ownership = .detachedPin
                        vertices[anchorID] = anchorVertex
                        
                        let newStaticPin = addVertex(at: pinPoint, ownership: pinOwnership)
                        self.dragState?.newVertices.insert(newStaticPin.id)
                        addEdge(from: anchorID, to: newStaticPin.id)
                        
                        // Now that it's detached, calculate its position and add to queue.
                        if wasHorizontal {
                            newPositions[anchorID] = CGPoint(x: anchorOrigPos.x, y: junctionNewPos.y)
                        } else {
                            newPositions[anchorID] = CGPoint(x: junctionNewPos.x, y: anchorOrigPos.y)
                        }
                        queue.append(anchorID)
                    }
                    // If not an off-axis pull, the pin is a rigid anchor. Do nothing.
                    
                } else {
                    // This is a regular free vertex. Propagate constraints.
                    if wasHorizontal {
                        newPositions[anchorID] = CGPoint(x: anchorOrigPos.x, y: junctionNewPos.y)
                    } else {
                        newPositions[anchorID] = CGPoint(x: junctionNewPos.x, y: anchorOrigPos.y)
                    }
                    queue.append(anchorID)
                }
            }
        }
        
        // MARK: - Finalization
        // Atomically apply all calculated positions.
        for (id, pos) in newPositions {
            self.moveVertex(id: id, to: pos)
        }
    }
    
    /// Call this when the drag gesture ends.
    /// It normalizes the graph and cleans up the temporary state.
    public func endDrag() {
        guard var state = dragState else { return }
        
        // After the drag, convert any temporarily detached pins back to free vertices.
        // Their wire to the actual pin is now a normal edge.
        for vertexID in vertices.keys {
            if let vertex = vertices[vertexID] {
                if case .detachedPin = vertex.ownership {
                    vertices[vertexID]?.ownership = .free
                }
            }
        }
        
        // Use the original vertex keys AND any new vertices to know which part of the graph was affected.
        var affectedVertices = Set(state.originalVertexPositions.keys)
        affectedVertices.formUnion(state.newVertices)
        normalize(around: affectedVertices)
        
        // Clean up
        self.dragState = nil
        onModelDidChange?()
    }
    
    // MARK: - Graph Normalization
    
    /// Normalizes the graph structure around a set of vertices.
    /// This involves merging coincident vertices and cleaning up collinear segments.
    func normalize(around verticesToCheck: Set<WireVertex.ID>) {
        let mergedVertices = mergeCoincidentVertices(in: verticesToCheck)
        
        var allAffectedVertices = verticesToCheck
        allAffectedVertices.formUnion(mergedVertices)
        
        // First, resolve any overlapping segments that may have been created by the merge.
        // This is crucial for correctly forming T-junctions.
        splitEdgesWithIntermediateVertices()
        
        // Now, clean up any redundant vertices on straight lines.
        for vertexID in allAffectedVertices {
            if vertices[vertexID] != nil {
                cleanupCollinearSegments(at: vertexID)
            }
        }
        // A second pass to clean up orphans created by the first pass
        for vertexID in allAffectedVertices where vertices[vertexID] != nil && (adjacency[vertexID]?.isEmpty ?? false) {
            if case .free = vertices[vertexID]?.ownership {
                removeVertex(id: vertexID)
            }
        }
    }
    
    private func splitEdgesWithIntermediateVertices() {
        var splits: [(edgeID: UUID, vertexID: UUID)] = []
        
        let allEdges = Array(edges.values)
        let allVertices = Array(vertices.values)
        
        for edge in allEdges {
            guard let p1 = vertices[edge.start]?.point, let p2 = vertices[edge.end]?.point else { continue }
            
            for vertex in allVertices {
                if vertex.id == edge.start || vertex.id == edge.end { continue }
                
                if isPoint(vertex.point, onSegmentBetween: p1, p2: p2) {
                    splits.append((edge.id, vertex.id))
                }
            }
        }
        
        guard !splits.isEmpty else { return }
        
        for split in splits {
            // The edge might have been removed by a previous split operation in this same loop
            guard let edgeToSplit = edges[split.edgeID] else { continue }
            
            let startID = edgeToSplit.start
            let endID = edgeToSplit.end
            
            removeEdge(id: edgeToSplit.id)
            addEdge(from: startID, to: split.vertexID)
            addEdge(from: split.vertexID, to: endID)
        }
    }
    
    private func cleanupCollinearSegments(at vertexID: WireVertex.ID) {
        guard let centerVertex = vertices[vertexID] else { return }
        // We only clean up free junctions. Pin-owned vertices are sacred.
        guard case .free = centerVertex.ownership else { return }
        processCollinearRun(for: centerVertex, isHorizontal: true)
        guard vertices[vertexID] != nil else { return } // The vertex might have been removed
        processCollinearRun(for: centerVertex, isHorizontal: false)
    }
    
    private func mergeCoincidentVertices(in scope: Set<WireVertex.ID>) -> Set<WireVertex.ID> {
        var verticesToProcess = scope.compactMap { vertices[$0] }
        var processedIDs: Set<WireVertex.ID> = []
        var modifiedVertices: Set<WireVertex.ID> = []
        let tolerance: CGFloat = 1e-6
        
        while let vertex = verticesToProcess.popLast() {
            if processedIDs.contains(vertex.id) { continue }
            
            let coincidentGroup = vertices.values.filter {
                hypot(vertex.point.x - $0.point.x, vertex.point.y - $0.point.y) < tolerance
            }
            
            if coincidentGroup.count > 1 {
                // Important: A pin-owned vertex always wins and becomes the survivor.
                let survivor = coincidentGroup.first(where: { if case .pin = $0.ownership { return true } else { return false } })
                ?? coincidentGroup.first!
                
                processedIDs.insert(survivor.id)
                modifiedVertices.insert(survivor.id)
                
                for victim in coincidentGroup where victim.id != survivor.id {
                    unifyNetIDs(between: survivor.id, and: victim.id)
                    
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
    
    private func processCollinearRun(for startVertex: WireVertex, isHorizontal: Bool) {
        var run: [WireVertex] = []
        var queue: [WireVertex] = [startVertex]
        var visitedIDs: Set<WireVertex.ID> = [startVertex.id]
        
        // 1. Find the entire continuous run of collinear vertices
        while let current = queue.popLast() {
            run.append(current)
            let (horizontal, vertical) = getCollinearNeighbors(for: current)
            (isHorizontal ? horizontal : vertical).forEach { neighbor in
                if !visitedIDs.contains(neighbor.id) {
                    visitedIDs.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }
        
        // A run of 2 is just a single segment, which cannot be simplified
        if run.count < 3 { return }
        
        // 2. Decide which vertices are topologically significant and must be kept
        var keptIDs: Set<WireVertex.ID> = []
        for vertex in run {
            // Always keep pin-owned vertices
            if case .pin = vertex.ownership {
                keptIDs.insert(vertex.id)
                continue
            }
            
            let (horizontal, vertical) = getCollinearNeighbors(for: vertex)
            let collinearNeighborCount = isHorizontal ? horizontal.count : vertical.count
            
            // Keep a vertex if it's a branch point (T-junction) or a true net endpoint.
            if (adjacency[vertex.id]?.count ?? 0) > collinearNeighborCount {
                keptIDs.insert(vertex.id)
            }
        }
        
        // Always preserve the absolute endpoints of the run
        if isHorizontal { run.sort { $0.point.x < $1.point.x } }
        else { run.sort { $0.point.y < $1.point.y } }
        
        if let first = run.first { keptIDs.insert(first.id) }
        if let last = run.last { keptIDs.insert(last.id) }
        
        // If no simplification is possible, exit
        if keptIDs.count >= run.count { return }
        
        // 3. Remove all the old edges that were part of the run
        let runIDs = Set(run.map { $0.id })
        for vertex in run where adjacency[vertex.id] != nil {
            for edgeID in Array(adjacency[vertex.id]!) {
                if let edge = edges[edgeID], runIDs.contains(edge.start == vertex.id ? edge.end : edge.start) {
                    removeEdge(id: edgeID)
                }
            }
        }
        
        // 4. Remove the redundant (not kept) vertices
        run.filter { !keptIDs.contains($0.id) }.forEach { removeVertex(id: $0.id) }
        
        // 5. Create new, simplified edges between the kept vertices
        let sortedKeptVertices = run.filter { keptIDs.contains($0.id) }
        if sortedKeptVertices.count < 2 { return }
        
        for i in 0..<(sortedKeptVertices.count - 1) {
            addEdge(from: sortedKeptVertices[i].id, to: sortedKeptVertices[i+1].id)
        }
    }
    
    // MARK: - Private Implementation
    
    private func connectStraightLine(from startVertex: WireVertex, to endVertex: WireVertex, affectedVertices: inout Set<WireVertex.ID>) {
        var verticesOnPath: [WireVertex] = [startVertex, endVertex]
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
    
    private func handleLShapeWire(from startVertex: WireVertex, to endVertex: WireVertex, strategy: WireConnectionStrategy, affectedVertices: inout Set<WireVertex.ID>) {
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
    private func addVertex(at point: CGPoint, ownership: VertexOwnership) -> WireVertex {
        let vertex = WireVertex(id: UUID(), point: point, ownership: ownership, netID: nil)
        vertices[vertex.id] = vertex
        adjacency[vertex.id] = []
        return vertex
    }
    
    @discardableResult
    private func addEdge(from startVertexID: WireVertex.ID, to endVertexID: WireVertex.ID) -> WireEdge? {
        guard vertices[startVertexID] != nil, vertices[endVertexID] != nil else { return nil }
        let isAlreadyConnected = adjacency[startVertexID]?.contains { edgeID in
            guard let edge = edges[edgeID] else { return false }
            return edge.start == endVertexID || edge.end == endVertexID
        } ?? false
        if isAlreadyConnected { return nil }
        
        let edge = WireEdge(id: UUID(), start: startVertexID, end: endVertexID)
        edges[edge.id] = edge
        adjacency[startVertexID]?.insert(edge.id)
        adjacency[endVertexID]?.insert(edge.id)
        return edge
    }
    
    @discardableResult
    private func splitEdgeAndInsertVertex(edgeID: UUID, at point: CGPoint, ownership: VertexOwnership = .free) -> WireVertex.ID? {
        guard let edgeToSplit = edges[edgeID] else { return nil }
        let startID = edgeToSplit.start
        let endID = edgeToSplit.end
        
        let originalNetID = vertices[startID]?.netID
        
        removeEdge(id: edgeID)
        let newVertex = addVertex(at: point, ownership: ownership)
        vertices[newVertex.id]?.netID = originalNetID
        
        addEdge(from: startID, to: newVertex.id)
        addEdge(from: newVertex.id, to: endID)
        return newVertex.id
    }
    
    private func removeVertex(id: WireVertex.ID) {
        if let connectedEdgeIDs = adjacency[id] {
            for edgeID in Array(connectedEdgeIDs) { removeEdge(id: edgeID) }
        }
        adjacency.removeValue(forKey: id)
        vertices.removeValue(forKey: id)
    }
    
    private func removeEdge(id: WireEdge.ID) {
        guard let edge = edges.removeValue(forKey: id) else { return }
        adjacency[edge.start]?.remove(id)
        adjacency[edge.end]?.remove(id)
    }
    
    // MARK: - Net Management
    
    private func findNeighbor(of vertexID: UUID, where predicate: (UUID, WireEdge) -> Bool) -> WireVertex? {
        guard let edges = adjacency[vertexID] else { return nil }
        for edgeID in edges {
            guard let edge = self.edges[edgeID] else { continue }
            let neighborID = edge.start == vertexID ? edge.end : edge.start
            if predicate(neighborID, edge) {
                return vertices[neighborID]
            }
        }
        return nil
    }
    
    private func unifyNetIDs(between vertex1ID: WireVertex.ID, and vertex2ID: WireVertex.ID) {
        let netID1 = vertices[vertex1ID]?.netID
        let netID2 = vertices[vertex2ID]?.netID
        
        if let id1 = netID1, let id2 = netID2 {
            if id1 != id2 {
                // Merge is required. Find the entire component, which is now connected,
                // and unify its ID. The component of vertex2 will be updated to id1.
                let (wholeComponent, _) = net(startingFrom: vertex2ID)
                for vID in wholeComponent {
                    vertices[vID]?.netID = id1
                }
                // Handle name merging
                if let oldName = netNames[id2], let newName = netNames[id1] {
                    if newName.hasPrefix("N$") && !oldName.hasPrefix("N$") {
                        netNames[id1] = oldName
                    }
                }
                netNames.removeValue(forKey: id2)
            }
        } else {
            // At least one of the vertices doesn't have a net ID.
            // Find the whole component and give it a single, consistent ID.
            let (wholeComponent, _) = net(startingFrom: vertex1ID) // Start traversal from either
            
            // Find an existing ID within the component, if any.
            let existingID = wholeComponent.compactMap { vertices[$0]?.netID }.first
            
            let finalNetID: UUID
            if let id = existingID {
                finalNetID = id
            } else {
                // No vertex in the new component had an ID. Create one.
                finalNetID = UUID()
                let netName = "N$\(nextNetNumber)"
                nextNetNumber += 1
                netNames[finalNetID] = netName
            }
            
            // Ensure all vertices in the component have this ID.
            for vID in wholeComponent {
                vertices[vID]?.netID = finalNetID
            }
        }
    }
    
    // MARK: - Graph Analysis
    func findVertex(at point: CGPoint) -> WireVertex? {
        let tolerance: CGFloat = 1e-6
        return vertices.values.first { value in abs(value.point.x - point.x) < tolerance && abs(value.point.y - point.y) < tolerance }
    }
    
    func findEdge(at point: CGPoint) -> WireEdge? {
        for edge in edges.values {
            guard let startVertex = vertices[edge.start], let endVertex = vertices[edge.end] else { continue }
            if isPoint(point, onSegmentBetween: startVertex.point, p2: endVertex.point) { return edge }
        }
        return nil
    }
    
    func findVertex(ownedBy ownerID: UUID, pinID: UUID) -> WireVertex.ID? {
        for vertex in vertices.values {
            if case .pin(let oID, let pID) = vertex.ownership, oID == ownerID, pID == pinID {
                return vertex.id
            }
        }
        return nil
    }
    
    private func getCollinearNeighbors(for centerVertex: WireVertex) -> (horizontal: [WireVertex], vertical: [WireVertex]) {
        guard let connectedEdgeIDs = adjacency[centerVertex.id] else { return ([], []) }
        var h:[WireVertex] = [], v:[WireVertex] = []
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
    
    func net(startingFrom startVertexID: WireVertex.ID) -> (vertices: Set<WireVertex.ID>, edges: Set<WireEdge.ID>) {
        var visitedVertices: Set<WireVertex.ID> = []
        var visitedEdges: Set<WireEdge.ID> = []
        var queue: [WireVertex.ID] = [startVertexID]
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
        var discoveredNets: [Net] = []
        var unvisitedVertices = Set(vertices.keys)
        
        // A dictionary to hold the disconnected components (islands) found for each original net ID.
        var componentsByNetID: [UUID: [[WireVertex.ID]]] = [:]
        
        // First pass: Discover all connected components (islands) and group them by their existing net ID.
        while let startVertexID = unvisitedVertices.first {
            let (componentVertices, componentEdges) = net(startingFrom: startVertexID)
            unvisitedVertices.subtract(componentVertices)
            
            // A component is only a valid net if it has edges. Otherwise, it's just floating pins.
            guard !componentEdges.isEmpty else {
                // As a cleanup, nullify the netID of these orphaned vertices.
                for vID in componentVertices {
                    vertices[vID]?.netID = nil
                }
                continue
            }
            
            // We use the first valid netID we find as the key.
            if let representativeNetID = componentVertices.compactMap({ vertices[$0]?.netID }).first {
                componentsByNetID[representativeNetID, default: []].append(Array(componentVertices))
            } else {
                // This component has no ID yet, so it's a new net.
                let newNetID = UUID()
                componentsByNetID[newNetID, default: []].append(Array(componentVertices))
            }
        }
        
        // Second pass: Reconcile splits and create the definitive list of nets.
        for (originalNetID, components) in componentsByNetID {
            if components.count == 1 {
                // No split detected for this net. Just ensure it has a name and update its vertices.
                let component = components[0]
                let (netVertices, netEdges) = net(startingFrom: component[0])
                
                let finalID = originalNetID
                if netNames[finalID] == nil {
                    netNames[finalID] = "N$\(nextNetNumber)"
                    nextNetNumber += 1
                }
                
                // Ensure all vertices are consistent, just in case.
                for vID in netVertices { vertices[vID]?.netID = finalID }
                
                discoveredNets.append(Net(id: finalID, name: netNames[finalID]!, vertexCount: netVertices.count, edgeCount: netEdges.count))
                
            } else {
                // A split was detected. The net with this ID has broken into multiple pieces.
                // Find the largest component to keep the original ID.
                var sortedComponents = components.sorted { $0.count > $1.count }
                
                // The largest component keeps the original ID and name.
                let mainComponent = sortedComponents.removeFirst()
                let (mainVertices, mainEdges) = net(startingFrom: mainComponent[0])
                for vID in mainVertices { vertices[vID]?.netID = originalNetID }
                
                if netNames[originalNetID] == nil {
                    netNames[originalNetID] = "N$\(nextNetNumber)"
                    nextNetNumber += 1
                }
                
                discoveredNets.append(Net(id: originalNetID, name: netNames[originalNetID]!, vertexCount: mainVertices.count, edgeCount: mainEdges.count))
                
                // All other, smaller components become new nets.
                for smallerComponent in sortedComponents {
                    let (newNetVertices, newNetEdges) = net(startingFrom: smallerComponent[0])
                    let newNetID = UUID()
                    let newNetName = "N$\(nextNetNumber)"
                    nextNetNumber += 1
                    netNames[newNetID] = newNetName
                    
                    for vID in newNetVertices { vertices[vID]?.netID = newNetID }
                    
                    discoveredNets.append(Net(id: newNetID, name: newNetName, vertexCount: newNetVertices.count, edgeCount: newNetEdges.count))
                }
            }
        }
        
        return discoveredNets
    }
    
    /// Synchronizes the positions of vertices owned by component pins.
    /// This method finds vertices that were loaded from the document and moves them to their correct,
    /// calculated positions based on the symbol's instance transform and pin definition.
    func syncPins(
        for symbolInstance: SymbolInstance,
        of symbolDefinition: Symbol,
        ownerID: UUID
    ) {
        for pinDef in symbolDefinition.pins {
            let rotatedPinPos = pinDef.position.applying(CGAffineTransform(rotationAngle: symbolInstance.rotation))
            let absolutePos = CGPoint(x: symbolInstance.position.x + rotatedPinPos.x,
                                      y: symbolInstance.position.y + rotatedPinPos.y)

            // Look for a vertex that was created by `build(from:)` for this specific pin.
            if let existingVertexID = findVertex(ownedBy: ownerID, pinID: pinDef.id) {
                // If found, move it from its placeholder location to the correct absolute position.
                moveVertex(id: existingVertexID, to: absolutePos)
            } else {
                // If no vertex exists, this component is new or not connected. Create a new pin vertex.
                getOrCreatePinVertex(at: absolutePos, ownerID: ownerID, pinID: pinDef.id)
            }
        }
    }
}
