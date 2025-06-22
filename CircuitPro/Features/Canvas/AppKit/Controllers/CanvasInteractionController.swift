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

        let deltaX = cursor.x - origin.x
        let deltaY = cursor.y - origin.y
        let rawAngle = atan2(deltaY, deltaX)

        var updated = canvas.elements
        for index in updated.indices where canvas.selectedIDs.contains(updated[index].id) {
            switch updated[index] {
            case .primitive(var primitive):
                var angle = rawAngle
                if !NSEvent.modifierFlags.contains(.shift) {
                    let snapIncrement: CGFloat = .pi / 12
                    angle = round(angle / snapIncrement) * snapIncrement
                }
                primitive.rotation = angle
                updated[index] = .primitive(primitive)

            case .pin(var pin):
            
                pin.rotation = rawAngle
                updated[index] = .pin(pin)

            case .pad(var pad):
          
                pad.rotation = rawAngle
                updated[index] = .pad(pad)

            case .symbol(var symbol):
                symbol.instance.rotation = rawAngle
                updated[index] = .symbol(symbol)

            case .connection(var c):
                c.segments = c.segments.map { segment in
                    let center = CGPoint(
                        x: (segment.0.x + segment.1.x) / 2,
                        y: (segment.0.y + segment.1.y) / 2
                    )
                    
                    let transformedStart = rotatePoint(segment.0, around: center, by: rawAngle)
                    let transformedEnd = rotatePoint(segment.1, around: center, by: rawAngle)
                    
                    return (transformedStart, transformedEnd)
                }
                updated[index] = .connection(c)
            }
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
                canvas.selectedIDs = Set(ids)
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
            canvas.needsDisplay = true
        }

        if !didMoveSignificantly, let newSel = tentativeSelection {
            canvas.selectedIDs = newSel
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

        let rawDX = loc.x - origin.x
        let rawDY = loc.y - origin.y

        // Only snap once
        let snappedDX = canvas.snapDelta(rawDX)
        let snappedDY = canvas.snapDelta(rawDY)

        var updated = canvas.elements
        for i in updated.indices {
            let id = updated[i].id
            guard let original = originalPositions[id] else { continue }

            let newPos = CGPoint(
                x: original.x + snappedDX,
                y: original.y + snappedDY
            )

            switch updated[i] {
            case .primitive(var p):
                p.position = newPos
                updated[i] = .primitive(p)

            case .pin(var p):
                p.position = newPos
                updated[i] = .pin(p)

            case .pad(var p):
                p.position = newPos
                updated[i] = .pad(p)

            case .symbol(var s):
                s.instance.position = newPos
                updated[i] = .symbol(s)

            case .connection(var c):
                c.segments = c.segments.map { segment in
                    let newStart = CGPoint(
                        x: segment.0.x + snappedDX,
                        y: segment.0.y + snappedDY
                    )
                    let newEnd = CGPoint(
                        x: segment.1.x + snappedDX,
                        y: segment.1.y + snappedDY
                    )
                    return (newStart, newEnd)
                }
                updated[i] = .connection(c)
            }
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
        if var tool = canvas.selectedTool, tool.id != "cursor" {
            let pinCount = canvas.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 }
            let padCount = canvas.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 }
            let context = CanvasToolContext(
                existingPinCount: pinCount,
                existingPadCount: padCount,
                selectedLayer: canvas.selectedLayer
            )

            let snapped = canvas.snap(loc)
            if let newElement = tool.handleTap(at: snapped, context: context) {
                canvas.elements.append(newElement)
                canvas.onUpdate?(canvas.elements)

                if case .primitive(let prim) = newElement {
                    canvas.onPrimitiveAdded?(prim.id, context.selectedLayer)
                }
            }

            canvas.selectedTool = tool
            return true
        }
        return false
    }
}
