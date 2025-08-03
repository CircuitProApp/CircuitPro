import AppKit

final class SelectionDragGesture: CanvasDragGesture {

    unowned let controller: CanvasController

    private var origin: CGPoint?
    private var didMove = false
    private let threshold: CGFloat = 4.0

    private var originalElementPositions: [UUID: CGPoint] = [:]
    private var originalTextPositions: [UUID: CGPoint] = [:]
    private var dragAnchor: (position: CGPoint, size: CGSize?, snapsToCenter: Bool)?

    init(controller: CanvasController) {
        self.controller = controller
    }

    func begin(at point: CGPoint, with hitTarget: CanvasHitTarget, event: NSEvent) -> Bool {
        let isDraggable = hitTarget.ownerPath.contains { controller.selectedIDs.contains($0) }
        guard isDraggable else {
            return false
        }

        origin = point
        didMove = false
        originalElementPositions.removeAll()
        originalTextPositions.removeAll()
        dragAnchor = nil

        // Set the drag anchor if we hit a CanvasElement.
        if let hitID = hitTarget.selectableID, let element = controller.elements.first(where: { $0.id == hitID }) {
            dragAnchor = (element.transformable.position, element.primitive?.size, element.primitive?.snapsToCenter ?? true)
        }

        // Cache positions of all selected CanvasElements.
        for element in controller.elements {
            if controller.selectedIDs.contains(element.id) {
                originalElementPositions[element.id] = element.transformable.position
                continue
            }
            if case .symbol(let symbol) = element {
                for text in symbol.anchoredTexts where controller.selectedIDs.contains(text.id) {
                    originalTextPositions[text.id] = text.position
                }
            }
        }
        
        // --- THIS IS THE FIX ---

        // Check if any of the selected IDs correspond to an edge in the schematic graph.
        let hasSelectedGraphEdge = controller.selectedIDs.contains { controller.schematicGraph.edges[$0] != nil }

        // The drag gesture is valid if we have cached element positions OR if we've selected an edge.
        guard !originalElementPositions.isEmpty || !originalTextPositions.isEmpty || hasSelectedGraphEdge else {
            // Nothing draggable was found in the selection. Abort.
            return false
        }
        
        // --- END FIX ---

        controller.schematicGraph.beginDrag(selectedIDs: controller.selectedIDs)

        return true
    }
    
    // The drag() and end() methods are already correct and need no changes.
    func drag(to point: CGPoint) {
        guard let origin = origin else { return }

        let rawDelta = point - origin
        if !didMove && hypot(rawDelta.x, rawDelta.y) < threshold {
            return
        }
        didMove = true

        let moveDelta = calculateSnappedDelta(rawDelta: rawDelta)

        if !originalElementPositions.isEmpty || !originalTextPositions.isEmpty {
            var updatedElements = controller.elements
            for i in updatedElements.indices {
                if let basePosition = originalElementPositions[updatedElements[i].id] {
                    updatedElements[i].moveTo(originalPosition: basePosition, offset: moveDelta)
                } else if case .symbol(var symbol) = updatedElements[i] {
                    var wasModified = false
                    for j in symbol.anchoredTexts.indices {
                        if let textBasePosition = originalTextPositions[symbol.anchoredTexts[j].id] {
                            symbol.anchoredTexts[j].position = textBasePosition + moveDelta
                            wasModified = true
                        }
                    }
                    if wasModified { updatedElements[i] = .symbol(symbol) }
                }
            }
            controller.elements = updatedElements
            controller.onUpdateElements?(updatedElements)
        }
        
        controller.schematicGraph.updateDrag(by: moveDelta)
    }

    private func calculateSnappedDelta(rawDelta: CGPoint) -> CGPoint {
        guard let anchor = dragAnchor else {
            // Wires don't have a single anchor, so they move by snapped grid increments.
            let snappedX = controller.snap(CGPoint(x: rawDelta.x, y: 0)).x
            let snappedY = controller.snap(CGPoint(x: 0, y: rawDelta.y)).y
            return CGPoint(x: snappedX, y: snappedY)
        }
        
        let newAnchorPos = anchor.position + rawDelta
        let snappedNewAnchorPos: CGPoint

        if let size = anchor.size, size != .zero, !anchor.snapsToCenter {
            let halfSize = CGPoint(x: size.width / 2, y: size.height / 2); let originalCorner = anchor.position - halfSize
            let newCorner = newAnchorPos - halfSize; let snappedNewCorner = controller.snap(newCorner)
            let cornerDelta = snappedNewCorner - originalCorner; snappedNewAnchorPos = anchor.position + cornerDelta
        } else {
            snappedNewAnchorPos = controller.snap(newAnchorPos)
        }
        return snappedNewAnchorPos - anchor.position
    }

    func end() {
        if didMove {
            controller.schematicGraph.endDrag()
        }
        origin = nil; dragAnchor = nil; didMove = false
        originalElementPositions.removeAll()
        originalTextPositions.removeAll()
    }
}
