import AppKit

final class CanvasInteractionController {

    unowned let canvas: CoreGraphicsCanvasView
    unowned let hitTestController: CanvasHitTestController

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

        // For connections, we gather the specific hit target.
        if tool.id == "connection" {
            context.hitTarget = hitTestController.hitTestForConnection(at: snapped)
        }
        context.clickCount = event.clickCount

        // The tool does its work and returns a new element, if any.
        if let newElement = tool.handleTap(at: snapped, context: context) {
            // The controller now decides how to integrate the new element.
            if case .connection(let newConn) = newElement {
                // If it's a connection, we use the hitTarget from our context to merge it.
                mergeConnection(newConn, onto: context.hitTarget)
            } else {
                // For any other element type, we just append it.
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
                mergeConnection(newConn, onto: nil) // No hit target on return
            } else {
                canvas.elements.append(newElement)
            }
            canvas.onUpdate?(canvas.elements)
        }
        canvas.selectedTool = tool
    }
    
    private func mergeConnection(_ newConn: ConnectionElement, onto hitTarget: ConnectionHitTarget?) {
        if let hit = hitTarget {
            switch hit {
            case .edge(_, let onConnectionID, _, _):
                if let index = canvas.elements.firstIndex(where: { $0.id == onConnectionID }) {
                    handleEdgeHit(newConnection: newConn, onExistingAtIndex: index, hit: hit)
                    return
                }
            case .vertex(_, let onConnectionID, _, _):
                if let index = canvas.elements.firstIndex(where: { $0.id == onConnectionID }) {
                    handleVertexHit(newConnection: newConn, onExistingAtIndex: index, hit: hit)
                    return
                }
            case .emptySpace:
                break // Fall through to geometric merge
            }
        }
        
        // Fallback for empty space taps or if the target element wasn't found
        performGeometricMerge(with: newConn)
    }

    /// Handles the case where a new connection is finalized on an existing edge.
    private func handleEdgeHit(newConnection: ConnectionElement, onExistingAtIndex index: Int, hit: ConnectionHitTarget) {
        guard case .connection(var existingConn) = canvas.elements[index],
              case .edge(let edgeID, _, let point, let hitOrientation) = hit else {
            return
        }

        // Determine the orientation of the new segment being added.
        let newOrientation = newConnection.graph.lastSegmentOrientation()

        // If the new segment is collinear with the hit edge, just merge and simplify.
        // This handles extending lines correctly.
        if newOrientation == hitOrientation {
            existingConn.graph.merge(with: newConnection.graph)
            existingConn.graph.simplifyCollinearSegments()
        } else {
            // Otherwise, it's a perpendicular hit, so create a T-junction.
            existingConn.graph.splitEdge(edgeID, at: point)
            existingConn.graph.merge(with: newConnection.graph)
            existingConn.graph.simplifyCollinearSegments()
        }

        canvas.elements[index] = .connection(existingConn)
        canvas.onUpdate?(canvas.elements)
    }

    /// Handles the case where a new connection is finalized on an existing vertex.
    private func handleVertexHit(newConnection: ConnectionElement, onExistingAtIndex index: Int, hit: ConnectionHitTarget) {
        guard case .connection(var existingConn) = canvas.elements[index] else {
            return
        }

        // For any vertex hit, the primary action is to merge the graphs.
        // The "straightening" of corners is handled implicitly by the simplification.
        // If a new segment is added that is collinear with an existing one at a corner,
        // the corner vertex will have two collinear edges after the merge, and
        // `simplifyCollinearSegments` will automatically remove it.
        existingConn.graph.merge(with: newConnection.graph)
        existingConn.graph.simplifyCollinearSegments()

        canvas.elements[index] = .connection(existingConn)
        canvas.onUpdate?(canvas.elements)
    }

    /// Fallback merge logic based on geometric proximity.
    private func performGeometricMerge(with newConn: ConnectionElement) {
        var indicesToMerge: [Int] = []
        let tolerance: CGFloat = 0.01

        for (index, element) in canvas.elements.enumerated() {
            guard case .connection(let existingConn) = element else { continue }
            if newConn.graph.isGeometricallyClose(to: existingConn.graph, tolerance: tolerance) {
                indicesToMerge.append(index)
            }
        }

        if indicesToMerge.isEmpty {
            canvas.elements.append(.connection(newConn))
        } else {
            let primaryIdx = indicesToMerge.first!
            if case .connection(var primaryConn) = canvas.elements[primaryIdx] {
                primaryConn.graph.merge(with: newConn.graph)
                
                for idx in indicesToMerge.dropFirst().sorted(by: >) {
                    if case .connection(let extraConn) = canvas.elements[idx] {
                        primaryConn.graph.merge(with: extraConn.graph)
                    }
                    canvas.elements.remove(at: idx)
                }
                primaryConn.graph.simplifyCollinearSegments()
                canvas.elements[primaryIdx] = .connection(primaryConn)
            }
        }
        canvas.onUpdate?(canvas.elements)
    }
}
