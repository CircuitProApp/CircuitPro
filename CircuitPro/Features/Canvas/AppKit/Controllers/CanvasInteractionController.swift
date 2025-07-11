import AppKit

final class CanvasInteractionController {

    unowned let canvas: CoreGraphicsCanvasView

    private var dragOrigin: CGPoint?
    private var tentativeSelection: Set<UUID>?
    private var originalPositions: [UUID: CGPoint] = [:]
    private var activeHandle: (UUID, Handle.Kind)?
    private var frozenOppositeWorld: CGPoint?
    private var didMoveSignificantly = false
    private let dragThreshold: CGFloat = 4.0

    private(set) var marqueeOrigin: CGPoint?
    private(set) var marqueeRect: CGRect? {
        didSet {
            // Tell the overlay view to redraw (may be nil → clears it)
            canvas.marqueeView?.rect = marqueeRect
        }
    }

    private var isRotatingViaMouse = false
    private var rotationOrigin: CGPoint?

    var isRotating: Bool { isRotatingViaMouse }

    init(canvas: CoreGraphicsCanvasView) {
        self.canvas = canvas
    }

    func enterRotationMode(around point: CGPoint) {
        isRotatingViaMouse = true
        rotationOrigin = point
    }

    func updateRotation(to cursor: CGPoint) {
        guard isRotatingViaMouse, let origin = rotationOrigin else { return }

        var angle = atan2(cursor.y - origin.y, cursor.x - origin.x)

        if !NSEvent.modifierFlags.contains(.shift) {
            let snap: CGFloat = .pi / 12            // 15°
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

    private func rotatePoint(_ point: CGPoint, around origin: CGPoint, by angle: CGFloat) -> CGPoint {
        let translatedX = point.x - origin.x
        let translatedY = point.y - origin.y

        let rotatedX = translatedX * cos(angle) - translatedY * sin(angle)
        let rotatedY = translatedX * sin(angle) + translatedY * cos(angle)

        return CGPoint(x: rotatedX + origin.x, y: rotatedY + origin.y)
    }

    func mouseDown(at loc: CGPoint, event: NSEvent) {
        if isRotatingViaMouse {
            isRotatingViaMouse = false
            rotationOrigin = nil
            return
        }

        if handleToolTap(at: loc) { return }

        beginInteraction(at: loc, event: event)

        if canvas.selectedTool?.id == "cursor",
           activeHandle == nil,
           canvas.hitRects.hitTest(at: loc) == nil {
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
                let ids = canvas.elements.filter {
                    $0.boundingBox.intersects(rect)
                }.map(\.id)
                canvas.marqueeSelectedIDs = Set(ids)
            }
            return
        }

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
                // Finished a marquee selection
                canvas.selectedIDs = canvas.marqueeSelectedIDs
            }
            // If marqueeOrigin is nil, it was an element drag, which is already handled.
        } else {
            // This was a click
            if let newSel = tentativeSelection {
                canvas.selectedIDs = newSel
            }
        }
    }

    // MARK: - Internal helpers
    private func beginInteraction(at loc: CGPoint, event: NSEvent) {
        dragOrigin = loc
        didMoveSignificantly = false
        tentativeSelection = nil
        originalPositions.removeAll()
        frozenOppositeWorld = nil
        activeHandle = nil

        if tryBeginHandleInteraction(at: loc) {
            return
        }

        tryUpdateTentativeSelection(at: loc, with: event)
    }

    private func tryBeginHandleInteraction(at loc: CGPoint) -> Bool {
        guard canvas.selectedIDs.count == 1 else { return false }

        let tolerance = 8.0 / canvas.magnification
        for element in canvas.elements where canvas.selectedIDs.contains(element.id) && element.isPrimitiveEditable {
            for handle in element.handles()
            where hypot(loc.x - handle.position.x, loc.y - handle.position.y) < tolerance {
                activeHandle = (element.id, handle.kind)
                if let oppositeKind = handle.kind.opposite,
                   let opposite = element.handles().first(where: { $0.kind == oppositeKind }) {
                    frozenOppositeWorld = opposite.position
                }
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
                        // Use the appropriate position for each element type
                        let position: CGPoint
                        if case .symbol(let symbol) = element {
                            position = symbol.instance.position
                        } else if let primitive = element.primitives.first {
                            position = primitive.position
                        } else {
                            continue
                        }
                        originalPositions[element.id] = position
                    }
                }
            } else {
                tentativeSelection = shift ? canvas.selectedIDs.union([id]) : [id]
            }

            if let element = canvas.elements.first(where: { $0.id == id }) {
                // Use the appropriate position for the hit element
                let position: CGPoint
                if case .symbol(let symbol) = element {
                    position = symbol.instance.position
                } else if let primitive = element.primitives.first {
                    position = primitive.position
                } else {
                    return
                }
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

    private func handleDraggingSelection(to loc: CGPoint, from origin: CGPoint) {
        guard !originalPositions.isEmpty else { return }

        let delta = CGPoint(
            x: canvas.snapDelta(loc.x - origin.x),
            y: canvas.snapDelta(loc.y - origin.y)
        )

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
    }

    private func handleToolTap(at loc: CGPoint) -> Bool {

        // 0 – any tool that is not the plain cursor
        if var tool = canvas.selectedTool, tool.id != "cursor" {

            // 1 – gather statistics
            let pinCount = canvas.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 }
            let padCount = canvas.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 }

            // 2 – snap the cursor to grid
            let snapped = canvas.snap(loc)

            // 3 – identify the element or segment that was clicked
            let hitID = canvas.hitRects.hitTest(at: snapped)

            // 4 – build the context handed to the tool
            let context = CanvasToolContext(
                existingPinCount: pinCount,
                existingPadCount: padCount,
                selectedLayer: canvas.selectedLayer,
                magnification: canvas.magnification,
                hitSegmentID: hitID
            )

            // 5 – let the tool react to the tap
            if let newElement = tool.handleTap(at: snapped, context: context) {

                switch newElement {

                case .connection(let newConn):

                    // Attempt to merge the newly created connection into an
                    // existing one that shares a vertex.

                    // 1) Collect indices of existing connection elements that
                    //    either share a vertex with the new connection *or*
                    //    have an edge that is intersected orthogonally by a
                    //    vertex of the new connection.  In the latter case we
                    //    first split that edge so that the two connections now
                    //    share an explicit vertex, allowing a straightforward
                    //    merge of their graphs.

                    var indicesToMerge: [Int] = []

                    let tolerance: CGFloat = 0.01

                    outer: for (index, element) in canvas.elements.enumerated() {
                        guard case .connection(let existingConn) = element else { continue }

                        var shareVertex = false

                        // a) Direct vertex overlap check.
                        vertexLoop: for vNew in newConn.graph.vertices.values {
                            for vOld in existingConn.graph.vertices.values {
                                let dx = vNew.point.x - vOld.point.x
                                let dy = vNew.point.y - vOld.point.y
                                if abs(dx) <= tolerance && abs(dy) <= tolerance {
                                    shareVertex = true
                                    break vertexLoop
                                }
                            }
                        }

                        // b) If no vertex overlap, check if any vertex of the
                        //    new connection lies on an edge of the existing
                        //    connection (within tolerance).  If so we split
                        //    that edge at the intersection, effectively
                        //    creating a shared vertex.

                        if !shareVertex {
                            intersectionCheck: for vNew in newConn.graph.vertices.values {
                                let p = vNew.point
                                for (edgeID, edge) in existingConn.graph.edges {
                                    guard let start = existingConn.graph.vertices[edge.start]?.point,
                                          let end   = existingConn.graph.vertices[edge.end]?.point else { continue }

                                    let isVertical   = start.x == end.x
                                    let isHorizontal = start.y == end.y

                                    if isVertical {
                                        // Check x alignment and y within range
                                        if abs(p.x - start.x) <= tolerance && p.y >= min(start.y, end.y) - tolerance && p.y <= max(start.y, end.y) + tolerance {
                                            // Ensure not at endpoints
                                            if !(abs(p.y - start.y) <= tolerance) && !(abs(p.y - end.y) <= tolerance) {
                                                _ = existingConn.graph.splitEdge(edgeID, at: p, tolerance: tolerance)
                                            }
                                            shareVertex = true
                                        }
                                    } else if isHorizontal {
                                        if abs(p.y - start.y) <= tolerance && p.x >= min(start.x, end.x) - tolerance && p.x <= max(start.x, end.x) + tolerance {
                                            if !(abs(p.x - start.x) <= tolerance) && !(abs(p.x - end.x) <= tolerance) {
                                                _ = existingConn.graph.splitEdge(edgeID, at: p, tolerance: tolerance)
                                            }
                                            shareVertex = true
                                        }
                                    }
                                }
                            }
                        }

                        // c) Also check if any vertex of the existing connection
                        //    lies on an edge of the new one.
                        if !shareVertex {
                            reverseIntersectionCheck: for vOld in existingConn.graph.vertices.values {
                                let p = vOld.point
                                for (edgeID, edge) in newConn.graph.edges {
                                    guard let start = newConn.graph.vertices[edge.start]?.point,
                                          let end   = newConn.graph.vertices[edge.end]?.point else { continue }

                                    let isVertical   = start.x == end.x
                                    let isHorizontal = start.y == end.y

                                    if isVertical {
                                        if abs(p.x - start.x) <= tolerance && p.y >= min(start.y, end.y) - tolerance && p.y <= max(start.y, end.y) + tolerance {
                                            if !(abs(p.y - start.y) <= tolerance) && !(abs(p.y - end.y) <= tolerance) {
                                                _ = newConn.graph.splitEdge(edgeID, at: p, tolerance: tolerance)
                                            }
                                            shareVertex = true
                                        }
                                    } else if isHorizontal {
                                        if abs(p.y - start.y) <= tolerance && p.x >= min(start.x, end.x) - tolerance && p.x <= max(start.x, end.x) + tolerance {
                                            if !(abs(p.x - start.x) <= tolerance) && !(abs(p.x - end.x) <= tolerance) {
                                                _ = newConn.graph.splitEdge(edgeID, at: p, tolerance: tolerance)
                                            }
                                            shareVertex = true
                                        }
                                    }
                                }
                            }
                        }

                        if shareVertex {
                            indicesToMerge.append(index)
                        }
                    }

                    if indicesToMerge.isEmpty {
                        // No overlap – simply add the new connection element.
                        canvas.elements.append(.connection(newConn))
                        newConn.graph.simplifyCollinearSegments() // Simplify after adding
                    } else {
                        // Merge into the first matching existing connection.
                        let primaryIdx = indicesToMerge.first!

                        if case .connection(let primaryConn) = canvas.elements[primaryIdx] {
                            primaryConn.graph.merge(with: newConn.graph)
                            primaryConn.graph.simplifyCollinearSegments() // Simplify after merge
                        }

                        // Merge additional overlapping connection elements into the primary one.
                        // Remove them from the canvas afterwards to avoid duplicates.
                        // NOTE: indicesToMerge is sorted ascending because we collected via enumerate.
                        // We'll iterate from the back to keep indices valid when removing.
                        for idx in indicesToMerge.dropFirst().sorted(by: >) {
                            if case .connection(let extraConn) = canvas.elements[idx] {
                                if case .connection(let primaryConn) = canvas.elements[primaryIdx] {
                                    primaryConn.graph.merge(with: extraConn.graph)
                                }
                            }
                            canvas.elements.remove(at: idx)
                        }
                        // Ensure the primary connection is simplified after all merges
                        if case .connection(let primaryConn) = canvas.elements[primaryIdx] {
                            primaryConn.graph.simplifyCollinearSegments()
                        }
                    }

                default:
                    canvas.elements.append(newElement)

                    // tell the document when a primitive was added
                    if case .primitive(let prim) = newElement {
                        canvas.onPrimitiveAdded?(prim.id, context.selectedLayer)
                    }
                }

                canvas.onUpdate?(canvas.elements)
            }

            // 6 – persist any state mutated inside the tool
            canvas.selectedTool = tool
            return true
        }
        return false
    }
}
