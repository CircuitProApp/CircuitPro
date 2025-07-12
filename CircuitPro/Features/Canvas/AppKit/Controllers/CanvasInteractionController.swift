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
    
    func reset() {
        resetInteractionState()
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
        let hitID = hitTestController.hitTest(at: loc)

        guard let id = hitID else {
            if !shift {
                tentativeSelection = []
            }
            return
        }

        let wasSelected = canvas.selectedIDs.contains(id)
        if wasSelected {
            tentativeSelection = canvas.selectedIDs.subtracting([id])
            if !shift {
                for element in canvas.elements where canvas.selectedIDs.contains(element.id) {
                    // Skip connection elements to disable their movement
                    if case .connection = element { continue }
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
            // Skip connection elements to disable their movement
            if case .connection = element { return }
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
            // Skip moving connections
            if case .connection = updated[i] { continue }
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
        guard var tool = canvas.selectedTool, tool.id != "cursor" else {
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
        }
        context.clickCount = event.clickCount

        // The tool does its work and returns a new element, if any.
        if let element = tool.handleTap(at: snapped, context: context) {
            canvas.elements.append(element)
            
            if case .primitive(let prim) = element {
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
            canvas.elements.append(newElement)
            canvas.onUpdate?(canvas.elements)
        }
        
        canvas.selectedTool = tool
    }
}
