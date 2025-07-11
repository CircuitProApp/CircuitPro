import AppKit

final class CanvasInteractionController {

    unowned let canvas: CoreGraphicsCanvasView
    unowned let hitTestController: CanvasHitTestController

    private var dragOrigin: CGPoint?
    private var tentativeSelection: Set<UUID>?
    private var originalPositions: [UUID: CGPoint] = [:]
    private var activeHandle: (UUID, Handle.Kind)?
    private var activeSegment: (connectionID: UUID, edgeID: UUID)?
    private var originalSegmentVertexPositions: (start: CGPoint, end: CGPoint)?
    private var affectedVertices: [UUID: CGPoint] = [:]
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

    var isRotating: Bool { isRotatingViaMouse }

    init(canvas: CoreGraphicsCanvasView, hitTestController: CanvasHitTestController) {
        self.canvas = canvas
        self.hitTestController = hitTestController
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

        if canvas.selectedTool?.id == "cursor", activeHandle == nil, activeSegment == nil, canvas.hitRects.hitTest(at: loc) == nil {
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

        if handleDraggingSegment(to: loc) { return }
        if handleDraggingHandle(to: loc) { return }
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
            } else if let activeSegment = activeSegment {
                if let connIndex = canvas.elements.firstIndex(where: { $0.id == activeSegment.connectionID }),
                   case .connection(var conn) = canvas.elements[connIndex] {
                    conn.graph.simplifyCollinearSegments()
                    conn.markChanged()
                    var updated = canvas.elements
                    updated[connIndex] = .connection(conn)
                    canvas.elements = updated
                    canvas.onUpdate?(updated)
                }
                if let newSel = tentativeSelection {
                    canvas.selectedIDs = newSel
                }
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
        activeSegment = nil
        originalSegmentVertexPositions = nil

        if tryBeginHandleInteraction(at: loc) { return }
        if tryBeginSegmentDragInteraction(at: loc) { return }
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

    private func tryBeginSegmentDragInteraction(at loc: CGPoint) -> Bool {
        let tolerance = 5.0 / canvas.magnification
        for element in canvas.elements.reversed() {
            guard case .connection(let conn) = element else { continue }
            if let edgeID = conn.hitSegmentID(at: loc, tolerance: tolerance) {
                activeSegment = (connectionID: conn.id, edgeID: edgeID)
                guard let edge = conn.graph.edges[edgeID],
                      let startVertex = conn.graph.vertices[edge.start],
                      let endVertex = conn.graph.vertices[edge.end] else {
                    activeSegment = nil
                    return false
                }
                originalPositions[conn.id] = .zero
                originalSegmentVertexPositions = (start: startVertex.point, end: endVertex.point)
                affectedVertices.removeAll()
                affectedVertices[startVertex.id] = startVertex.point
                affectedVertices[endVertex.id] = endVertex.point
                func cacheNeighbors(for vertex: ConnectionVertex) {
                    guard let neighborEdges = conn.graph.adjacency[vertex.id] else { return }
                    for neighborEdgeID in neighborEdges where neighborEdgeID != edgeID {
                        guard let neighborEdge = conn.graph.edges[neighborEdgeID] else { continue }
                        let neighborID = (neighborEdge.start == vertex.id) ? neighborEdge.end : neighborEdge.start
                        if let neighborVertex = conn.graph.vertices[neighborID] {
                            affectedVertices[neighborVertex.id] = neighborVertex.point
                        }
                    }
                }
                cacheNeighbors(for: startVertex)
                cacheNeighbors(for: endVertex)
                tentativeSelection = [edgeID]
                return true
            }
        }
        return false
    }

    private func tryUpdateTentativeSelection(at loc: CGPoint, with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let hitID = canvas.hitRects.hitTest(at: loc)
        if let id = hitID {
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
        } else if !shift {
            tentativeSelection = []
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

    private func handleDraggingSegment(to loc: CGPoint) -> Bool {
        guard let activeSegment = activeSegment, let origin = dragOrigin, let originalPositions = originalSegmentVertexPositions else { return false }
        guard let connIndex = canvas.elements.firstIndex(where: { $0.id == activeSegment.connectionID }),
              case .connection(var conn) = canvas.elements[connIndex] else { return false }
        let deltaX = loc.x - origin.x, deltaY = loc.y - origin.y
        let snappedDeltaX = canvas.snapDelta(deltaX), snappedDeltaY = canvas.snapDelta(deltaY)
        for (vertexID, originalPos) in affectedVertices { conn.graph.vertices[vertexID]?.point = originalPos }
        guard let draggedEdge = conn.graph.edges[activeSegment.edgeID] else { return false }
        let isDraggedEdgeHorizontal = abs(originalPositions.start.y - originalPositions.end.y) < 0.01
        let parallelDeltaX = isDraggedEdgeHorizontal ? snappedDeltaX : 0, parallelDeltaY = isDraggedEdgeHorizontal ? 0 : snappedDeltaY
        for (vertexID, originalPos) in affectedVertices {
            guard let vertex = conn.graph.vertices[vertexID] else { continue }
            let isDraggedSegmentVertex = (vertexID == draggedEdge.start || vertexID == draggedEdge.end)
            if isDraggedSegmentVertex {
                vertex.point = CGPoint(x: originalPos.x + snappedDeltaX, y: originalPos.y + snappedDeltaY)
            } else {
                vertex.point = CGPoint(x: originalPos.x + parallelDeltaX, y: originalPos.y + parallelDeltaY)
            }
        }
        conn.markChanged()
        var updated = canvas.elements
        updated[connIndex] = .connection(conn)
        canvas.elements = updated
        canvas.onUpdate?(updated)
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
        activeSegment = nil
        originalSegmentVertexPositions = nil
    }

    private func handleToolTap(at loc: CGPoint, event: NSEvent) -> Bool {
        guard var tool = canvas.selectedTool, tool.id != "cursor" else { return false }

        let snapped = canvas.snap(loc)
        var context = CanvasToolContext(
            existingPinCount: canvas.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 },
            existingPadCount: canvas.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 },
            selectedLayer: canvas.selectedLayer,
            magnification: canvas.magnification
        )

        if tool.id == "connection" {
            context.hitTarget = hitTestController.hitTestForConnection(at: snapped)
        }
        // Propagate click count for double-tap handling.
        context.clickCount = event.clickCount

        if let newElement = tool.handleTap(at: snapped, context: context) {
            if case .connection(let newConn) = newElement {
                mergeConnection(newConn)
            } else {
                canvas.elements.append(newElement)
            }
            
            if case .primitive(let prim) = newElement {
                canvas.onPrimitiveAdded?(prim.id, context.selectedLayer)
            }
            canvas.onUpdate?(canvas.elements)
        }

        canvas.selectedTool = tool
        return true
    }

    func handleReturnKeyPress() {
        guard var tool = canvas.selectedTool, tool.id == "connection" else { return }
        if let newElement = tool.handleReturn() {
            if case .connection(let newConn) = newElement {
                mergeConnection(newConn)
            } else {
                canvas.elements.append(newElement)
            }
            canvas.onUpdate?(canvas.elements)
        }
        canvas.selectedTool = tool
    }
    
    private func mergeConnection(_ newConn: ConnectionElement) {
        var indicesToMerge: [Int] = []
        let tolerance: CGFloat = 0.01

        for (index, element) in canvas.elements.enumerated() {
            guard case .connection(let existingConn) = element else { continue }
            var isRelated = false

            for vNew in newConn.graph.vertices.values {
                for vOld in existingConn.graph.vertices.values {
                    if abs(vNew.point.x - vOld.point.x) <= tolerance && abs(vNew.point.y - vOld.point.y) <= tolerance {
                        isRelated = true
                        break
                    }
                }
                if isRelated { break }
            }

            if !isRelated {
                for vNew in newConn.graph.vertices.values {
                    let p = vNew.point
                    for (edgeID, edge) in existingConn.graph.edges {
                        guard let start = existingConn.graph.vertices[edge.start]?.point,
                              let end = existingConn.graph.vertices[edge.end]?.point else { continue }
                        if (abs(p.x - start.x) <= tolerance && p.y >= min(start.y, end.y) - tolerance && p.y <= max(start.y, end.y) + tolerance) ||
                           (abs(p.y - start.y) <= tolerance && p.x >= min(start.x, end.x) - tolerance && p.x <= max(start.x, end.x) + tolerance) {
                            _ = existingConn.graph.splitEdge(edgeID, at: p, tolerance: tolerance)
                            isRelated = true
                            break
                        }
                    }
                    if isRelated { break }
                }
            }
            
            if isRelated {
                indicesToMerge.append(index)
            }
        }

        if indicesToMerge.isEmpty {
            canvas.elements.append(.connection(newConn))
        } else {
            let primaryIdx = indicesToMerge.first!
            if case .connection(var primaryConn) = canvas.elements[primaryIdx] {
                primaryConn.graph.merge(with: newConn.graph)
                canvas.elements[primaryIdx] = .connection(primaryConn)
                
                for idx in indicesToMerge.dropFirst().sorted(by: >) {
                    if case .connection(let extraConn) = canvas.elements[idx] {
                        primaryConn.graph.merge(with: extraConn.graph)
                        canvas.elements[primaryIdx] = .connection(primaryConn)
                    }
                    canvas.elements.remove(at: idx)
                }
                primaryConn.graph.simplifyCollinearSegments()
                canvas.elements[primaryIdx] = .connection(primaryConn)
            }
        }
    }
}
