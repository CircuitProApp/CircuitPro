import AppKit

final class CanvasInteractionController {

    unowned let canvas: CoreGraphicsCanvasView
    unowned let hitTestController: CanvasHitTestController

    private var dragOrigin: CGPoint?
    private var tentativeSelection: Set<UUID>?
    private var originalPositions: [UUID: CGPoint] = [:]

    // Connection Dragging State
    private var activeConnectionID: UUID?
    private var draggedEdgeID: UUID?
    private var originalGraphVertexPositions: [UUID: CGPoint]?

    private var activeHandle: (UUID, Handle.Kind)?
    private var frozenOppositeWorld: CGPoint?
    private var didMoveSignificantly = false
    private let dragThreshold: CGFloat = 4.0

    private(set) var marqueeOrigin: CGPoint?
    private(set) var marqueeRect: CGRect? {
        didSet {
            canvas.marqueeView?.rect = marqueeRect
        }
    }

    private var isRotatingViaMouse = false
    private var rotationOrigin: CGPoint?
    
    private var initialConnectionHitTarget: ConnectionHitTarget?

    var isRotating: Bool { isRotatingViaMouse }

    init(canvas: CoreGraphicsCanvasView, hitTestController: CanvasHitTestController) {
        self.canvas = canvas
        self.hitTestController = hitTestController
    }
    
    func reset() {
        resetInteractionState()
        initialConnectionHitTarget = nil
    }

    func enterRotationMode(around point: CGPoint) {
        isRotatingViaMouse = true
        rotationOrigin = point
    }

    func updateRotation(to cursor: CGPoint) {
        guard isRotatingViaMouse, let origin = rotationOrigin else { return }
        var angle = atan2(cursor.y - origin.y, cursor.x - origin.x)
        if !NSEvent.modifierFlags.contains(.shift) {
            let snap: CGFloat = .pi / 12
            angle = round(angle / snap) * snap
        }
        var updated = canvas.elements
        for i in updated.indices where canvas.selectedIDs.contains(updated[i].id) {
            updated[i].setRotation(angle)
        }
        canvas.elements = updated
        canvas.onUpdate?(updated)
        canvas.needsDisplay = true
    }

    func mouseDown(at loc: CGPoint, event: NSEvent) {
        if isRotatingViaMouse {
            isRotatingViaMouse = false
            rotationOrigin = nil
            return
        }

        if handleToolTap(at: loc, event: event) { return }

        beginInteraction(at: loc, event: event)

        if canvas.selectedTool?.id == "cursor", activeHandle == nil, canvas.hitRects.hitTest(at: loc) == nil {
            marqueeOrigin = loc
            marqueeRect = nil
        }
    }

    func mouseDragged(to loc: CGPoint, event: NSEvent) {
        guard let origin = dragOrigin else { return }
        updateMovementState(from: origin, to: loc)

        if let origin = marqueeOrigin, canvas.selectedTool?.id == "cursor" {
            marqueeRect = CGRect(origin: origin, size: .zero).union(CGRect(origin: loc, size: .zero))
            if let rect = marqueeRect {
                let ids = canvas.elements.filter { $0.boundingBox.intersects(rect) }.map(\.id)
                canvas.marqueeSelectedIDs = Set(ids)
            }
            return
        }

        if handleDraggingHandle(to: loc) { return }
        if handleDraggingConnectionEdge(to: loc, from: origin) { return }
        handleDraggingSelection(to: loc, from: origin)
    }

    func mouseUp(at loc: CGPoint, event: NSEvent) {
        defer {
            resetInteractionState()
            marqueeOrigin = nil
            marqueeRect = nil
            canvas.marqueeSelectedIDs.removeAll()
            canvas.needsDisplay = true
        }

        if didMoveSignificantly {
            if marqueeOrigin != nil {
                canvas.selectedIDs = canvas.marqueeSelectedIDs
            }
        } else {
            if let newSel = tentativeSelection {
                canvas.selectedIDs = newSel
            }
        }
    }

    private func beginInteraction(at loc: CGPoint, event: NSEvent) {
        dragOrigin = loc
        didMoveSignificantly = false
        tentativeSelection = nil
        originalPositions.removeAll()
        frozenOppositeWorld = nil
        activeHandle = nil
        
        resetConnectionDragState()

        if tryBeginHandleInteraction(at: loc) { return }
        tryUpdateTentativeSelection(at: loc, with: event)
    }

    private func tryBeginHandleInteraction(at loc: CGPoint) -> Bool {
        guard canvas.selectedIDs.count == 1 else { return false }
        let tolerance = 8.0 / canvas.magnification
        for element in canvas.elements where canvas.selectedIDs.contains(element.id) && element.isPrimitiveEditable {
            for handle in element.handles() where hypot(loc.x - handle.position.x, loc.y - handle.position.y) < tolerance {
                activeHandle = (element.id, handle.kind)
                if let oppositeKind = handle.kind.opposite, let opposite = element.handles().first(where: { $0.kind == oppositeKind }) {
                    frozenOppositeWorld = opposite.position
                }
                return true
            }
        }
        return false
    }

    private func tryUpdateTentativeSelection(at loc: CGPoint, with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let hitID = hitTestController.hitTest(at: loc)

        guard let id = hitID else {
            if !shift {
                tentativeSelection = []
            }
            return
        }

        // Prioritize edge hits for drag operations.
        for element in canvas.elements {
            guard case .connection(let conn) = element, conn.graph.edges[id] != nil else { continue }
            
            // This is an edge. Start a drag operation for this connection.
            tentativeSelection = [id]
            activeConnectionID = conn.id
            draggedEdgeID = id
            originalGraphVertexPositions = conn.graph.vertices.mapValues { $0.point }
            return // Handled
        }

        // If no edge was hit, it must be an element. Fall back to original logic.
        let wasSelected = canvas.selectedIDs.contains(id)
        if wasSelected {
            tentativeSelection = canvas.selectedIDs.subtracting([id])
            if !shift {
                for element in canvas.elements where canvas.selectedIDs.contains(element.id) {
                    let position: CGPoint
                    if case .symbol(let symbol) = element { position = symbol.instance.position }
                    else if let primitive = element.primitives.first { position = primitive.position }
                    else { continue }
                    originalPositions[element.id] = position
                }
            }
        } else {
            tentativeSelection = shift ? canvas.selectedIDs.union([id]) : [id]
        }
        if let element = canvas.elements.first(where: { $0.id == id }) {
            let position: CGPoint
            if case .symbol(let symbol) = element { position = symbol.instance.position }
            else if let primitive = element.primitives.first { position = primitive.position }
            else { return }
            originalPositions[id] = position
        }
    }

    private func updateMovementState(from origin: CGPoint, to loc: CGPoint) {
        if !didMoveSignificantly && hypot(loc.x - origin.x, loc.y - origin.y) >= dragThreshold {
            didMoveSignificantly = true
        }
    }

    private func handleDraggingHandle(to loc: CGPoint) -> Bool {
        guard let (id, kind) = activeHandle else { return false }
        var updated = canvas.elements
        let snapped = canvas.snap(loc)
        for i in updated.indices where updated[i].id == id {
            updated[i].updateHandle(kind, to: snapped, opposite: frozenOppositeWorld)
            canvas.elements = updated
            canvas.onUpdate?(updated)
            return true
        }
        return false
    }

    private func handleDraggingConnectionEdge(to loc: CGPoint, from origin: CGPoint) -> Bool {
        guard let activeConnectionID = self.activeConnectionID,
              let draggedEdgeID = self.draggedEdgeID,
              let originalGraphPositions = self.originalGraphVertexPositions,
              let elementIndex = canvas.elements.firstIndex(where: { $0.id == activeConnectionID }),
              case .connection(var conn) = canvas.elements[elementIndex],
              let draggedEdge = conn.graph.edges[draggedEdgeID]
        else {
            return false
        }

        let delta = CGPoint(x: canvas.snapDelta(loc.x - origin.x), y: canvas.snapDelta(loc.y - origin.y))
        var vertexDeltas: [UUID: CGPoint] = [:]

        // The dragged edge's vertices move by the full delta.
        vertexDeltas[draggedEdge.start] = delta
        vertexDeltas[draggedEdge.end] = delta

        // For each vertex of the dragged edge, find adjacent orthogonal edges and constrain their far-end movement.
        for vertexID in [draggedEdge.start, draggedEdge.end] {
            guard let adjacentEdgeIDs = conn.graph.adjacency[vertexID] else { continue }
            
            for adjacentEdgeID in adjacentEdgeIDs where adjacentEdgeID != draggedEdgeID {
                guard let adjacentEdge = conn.graph.edges[adjacentEdgeID],
                      let startPos = originalGraphPositions[adjacentEdge.start],
                      let endPos = originalGraphPositions[adjacentEdge.end]
                else { continue }

                let farVertexID = (adjacentEdge.start == vertexID) ? adjacentEdge.end : adjacentEdge.start
                
                // Determine orientation from original positions
                let tolerance: CGFloat = 0.01
                if abs(startPos.x - endPos.x) < tolerance { // Vertical
                    vertexDeltas[farVertexID] = CGPoint(x: delta.x, y: 0)
                } else if abs(startPos.y - endPos.y) < tolerance { // Horizontal
                    vertexDeltas[farVertexID] = CGPoint(x: 0, y: delta.y)
                }
            }
        }
        
        // Apply the calculated deltas to the graph
        for (vertexID, vertexDelta) in vertexDeltas {
            if let originalPos = originalGraphPositions[vertexID] {
                conn.graph.vertices[vertexID]?.point = CGPoint(x: originalPos.x + vertexDelta.x, y: originalPos.y + vertexDelta.y)
            }
        }
        
        conn.markChanged()
        canvas.elements[elementIndex] = .connection(conn)
        canvas.onUpdate?(canvas.elements)

        return true
    }

    private func handleDraggingSelection(to loc: CGPoint, from origin: CGPoint) {
        guard !originalPositions.isEmpty else { return }
        let delta = CGPoint(x: canvas.snapDelta(loc.x - origin.x), y: canvas.snapDelta(loc.y - origin.y))
        var updated = canvas.elements
        for i in updated.indices {
            guard let orig = originalPositions[updated[i].id] else { continue }
            updated[i].moveTo(originalPosition: orig, offset: delta)
        }
        canvas.elements = updated
        canvas.onUpdate?(updated)
    }

    private func resetInteractionState() {
        dragOrigin = nil
        originalPositions.removeAll()
        didMoveSignificantly = false
        activeHandle = nil
        frozenOppositeWorld = nil
        resetConnectionDragState()
    }
    
    private func resetConnectionDragState() {
        activeConnectionID = nil
        draggedEdgeID = nil
        originalGraphVertexPositions = nil
    }

    private func handleToolTap(at loc: CGPoint, event: NSEvent) -> Bool {
        guard var tool = canvas.selectedTool, tool.id != "cursor" else {
            // If another tool is selected, reset any lingering connection state.
            initialConnectionHitTarget = nil
            return false
        }

        let snapped = canvas.snap(loc)
        var context = CanvasToolContext(
            existingPinCount: canvas.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 },
            existingPadCount: canvas.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 },
            selectedLayer: canvas.selectedLayer,
            magnification: canvas.magnification
        )

        // For connections, we gather the specific hit target.
        if tool.id == "connection" {
            context.hitTarget = hitTestController.hitTestForConnection(at: snapped)
            // If this is the first tap of a new connection, store the hit target.
            if initialConnectionHitTarget == nil {
                initialConnectionHitTarget = context.hitTarget
            }
        }
        context.clickCount = event.clickCount

        // The tool does its work and returns a new element, if any.
        let newElement = tool.handleTap(at: snapped, context: context)
        
        if let element = newElement {
            // The controller now decides how to integrate the new element.
            if case .connection(let newConn) = element {
                var mergeTarget = context.hitTarget
                // If the final tap was in empty space, use the initial hit target we stored.
                if case .some(.emptySpace) = mergeTarget {
                    mergeTarget = initialConnectionHitTarget
                }
                mergeConnection(newConn, onto: mergeTarget)
            } else {
                // For any other element type, we just append it.
                canvas.elements.append(element)
            }
            
            if case .primitive(let prim) = element {
                canvas.onPrimitiveAdded?(prim.id, context.selectedLayer)
            }
            canvas.onUpdate?(canvas.elements)
            
            // A new element was created, so the drawing session is complete.
            initialConnectionHitTarget = nil
        }

        canvas.selectedTool = tool
        return true
    }

    func handleReturnKeyPress() {
        guard var tool = canvas.selectedTool, tool.id == "connection" else { return }
        
        if let newElement = tool.handleReturn() {
            if case .connection(let newConn) = newElement {
                // Use the initial hit target for merges initiated by the return key.
                mergeConnection(newConn, onto: initialConnectionHitTarget)
            } else {
                canvas.elements.append(newElement)
            }
            canvas.onUpdate?(canvas.elements)
        }
        
        // The drawing session is complete.
        initialConnectionHitTarget = nil
        canvas.selectedTool = tool
    }
    
    private func mergeConnection(_ newConn: ConnectionElement, onto finalHitTarget: ConnectionHitTarget?) {
        // Split any existing edges tapped at the start or end so junctions form immediately.
        if let hit = initialConnectionHitTarget, case .edge(let edgeID, let onConnID, let point, _) = hit,
           let idx = canvas.elements.firstIndex(where: { $0.id == onConnID }),
           case .connection(var conn) = canvas.elements[idx] {
            conn.graph.splitEdge(edgeID, at: point)
            canvas.elements[idx] = .connection(conn)
        }
        if let hit = finalHitTarget, case .edge(let edgeID, let onConnID, let point, _) = hit,
           let idx = canvas.elements.firstIndex(where: { $0.id == onConnID }),
           case .connection(var conn) = canvas.elements[idx] {
            conn.graph.splitEdge(edgeID, at: point)
            canvas.elements[idx] = .connection(conn)
        }
        var allHitElements = Set<UUID>()

        // 1. Collect the element ID from the final hit target.
        if let hit = finalHitTarget {
            switch hit {
            case .edge(_, let onConnectionID, _, _), .vertex(_, let onConnectionID, _, _):
                allHitElements.insert(onConnectionID)
            case .emptySpace:
                break
            }
        }

        // 2. Collect the element ID from the initial hit target.
        if let hit = initialConnectionHitTarget {
            switch hit {
            case .edge(_, let onConnectionID, _, _), .vertex(_, let onConnectionID, _, _):
                allHitElements.insert(onConnectionID)
            case .emptySpace:
                break
            }
        }

        // 3. If no specific elements were hit, just do a standard geometric merge.
        if allHitElements.isEmpty {
            performGeometricMerge(with: newConn)
            return
        }

        // 4. We have specific elements to merge. Get their indices.
        let indicesToMerge = allHitElements
            .compactMap { id in canvas.elements.firstIndex(where: { $0.id == id }) }
            .sorted(by: >) // Sort descending to remove elements safely.

        // 5. Get the primary connection to merge into.
        guard let primaryIndex = indicesToMerge.last,
              case .connection(var primaryConn) = canvas.elements[primaryIndex] else {
            // This should not happen if allHitElements is not empty, but as a safeguard:
            performGeometricMerge(with: newConn)
            return
        }

        // 6. Merge the new connection's graph into the primary one.
        primaryConn.graph.merge(with: newConn.graph)

        // 7. Merge all other hit connections into the primary one.
        for index in indicesToMerge {
            if index == primaryIndex { continue }
            if case .connection(let extraConn) = canvas.elements[index] {
                primaryConn.graph.merge(with: extraConn.graph)
            }
        }
        
        // 8. Clean up the graph topology.
        primaryConn.graph.simplifyCollinearSegments()
        
        // 9. Update the primary element on the canvas.
        canvas.elements[primaryIndex] = .connection(primaryConn)

        // 10. Remove the other merged elements.
        for index in indicesToMerge {
            if index == primaryIndex { continue }
            canvas.elements.remove(at: index)
        }
        
        canvas.onUpdate?(canvas.elements)
    }

    /// Fallback merge logic based on geometric proximity.
    private func performGeometricMerge(with newConn: ConnectionElement) {
        var indicesToMerge: [Int] = []
        let tolerance: CGFloat = 0.01

        for (index, element) in canvas.elements.enumerated() {
            guard case .connection(let existingConn) = element else { continue }
            if newConn.graph.isGeometricallyClose(to: existingConn.graph, tolerance: tolerance) ||
               existingConn.graph.isGeometricallyClose(to: newConn.graph, tolerance: tolerance) {
                indicesToMerge.append(index)
            }
        }

        if indicesToMerge.isEmpty {
            canvas.elements.append(.connection(newConn))
        } else {
            let primaryIdx = indicesToMerge.first!
            guard case .connection(var primaryConn) = canvas.elements[primaryIdx] else {
                canvas.elements.append(.connection(newConn))
                return
            }

            let otherConnections = indicesToMerge.dropFirst().compactMap { idx -> ConnectionElement? in
                guard case .connection(let conn) = canvas.elements[idx] else { return nil }
                return conn
            }
            var allOtherGraphs = otherConnections.map { $0.graph }
            allOtherGraphs.append(newConn.graph)

            // Merge all graphs into the primary one.
            for otherGraph in allOtherGraphs {
                primaryConn.graph.merge(with: otherGraph)
            }

            // Clean up topology and update canvas.
            primaryConn.graph.simplifyCollinearSegments()
            canvas.elements[primaryIdx] = .connection(primaryConn)

            // Remove the other merged elements.
            for idx in indicesToMerge.dropFirst().sorted(by: >) {
                canvas.elements.remove(at: idx)
            }
        }
        canvas.onUpdate?(canvas.elements)
    }
}
