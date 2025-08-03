import AppKit

final class SelectionDragGesture: CanvasDragGesture {

    unowned let controller: CanvasController

    private var origin: CGPoint?
    private var didMove = false
    private let threshold: CGFloat = 4.0

    // Caches for original positions of items being dragged.
    private var originalElementPositions: [UUID: CGPoint] = [:]
    
    // The anchor point for grid-snapping, based on the item clicked.
    private var dragAnchor: (position: CGPoint, size: CGSize?, snapsToCenter: Bool)?

    init(controller: CanvasController) {
        self.controller = controller
    }

    /// Tries to begin a drag gesture for the current selection.
    /// This should be called by the input coordinator *after* a hit has been confirmed.
    /// - Returns: `true` if a drag gesture was successfully initiated.
    func begin(at point: CGPoint, with hitTarget: CanvasHitTarget, event: NSEvent) -> Bool {
        // An item is draggable if any part of its ownership chain is in the selection set.
        let isDraggable = hitTarget.ownerPath.contains { controller.selectedIDs.contains($0) }
        guard isDraggable else {
            return false
        }

        // Set the anchor point for the drag. This is the starting position of the
        // item actually hit by the cursor, allowing for correct grid snapping.
        if let hitID = hitTarget.selectableID, let element = controller.elements.first(where: { $0.id == hitID }) {
            let position = element.transformable.position
            let size = element.primitive?.size
            let snapsToCenter = element.primitive?.snapsToCenter ?? true // Default to center snapping
            dragAnchor = (position, size, snapsToCenter)
        }

        origin = point
        didMove = false
        originalElementPositions.removeAll()

        // Cache positions of all selected items.
        for element in controller.elements where controller.selectedIDs.contains(element.id) {
            originalElementPositions[element.id] = element.transformable.position
        }

        // Tell the schematic graph to prepare its vertices for the drag.
        controller.schematicGraph.beginDrag(selectedIDs: controller.selectedIDs)

        return true
    }

    // MARK: - Drag
    
    func drag(to point: CGPoint) {
        guard let origin = origin else { return }

        let rawDelta = point - origin

        // Don't start the drag until the mouse has moved beyond a small threshold.
        if !didMove && hypot(rawDelta.x, rawDelta.y) < threshold {
            return
        }
        didMove = true

        // Calculate the correctly snapped move delta based on the drag anchor.
        let moveDelta = calculateSnappedDelta(rawDelta: rawDelta)

        // Part 1: Move all selected canvas elements.
        if !originalElementPositions.isEmpty {
            var updatedElements = controller.elements
            for i in updatedElements.indices {
                if let basePosition = originalElementPositions[updatedElements[i].id] {
                    updatedElements[i].moveTo(originalPosition: basePosition, offset: moveDelta)
                }
            }
            // Mutate the controller's state directly.
            controller.elements = updatedElements
        }

        // Part 2: Update the schematic graph drag.
        controller.schematicGraph.updateDrag(by: moveDelta)
    }

    private func calculateSnappedDelta(rawDelta: CGPoint) -> CGPoint {
        guard let anchor = dragAnchor else {
            // Fallback for safety, though anchor should always be set.
            let snappedX = controller.snap(CGPoint(x: rawDelta.x, y: 0)).x
            let snappedY = controller.snap(CGPoint(x: 0, y: rawDelta.y)).y
            return CGPoint(x: snappedX, y: snappedY)
        }
        
        let newAnchorPos = anchor.position + rawDelta
        let snappedNewAnchorPos: CGPoint

        // Use corner-snapping for resizable primitives, center-snapping for others.
        if let size = anchor.size, size != .zero, !anchor.snapsToCenter {
            let halfSize = CGPoint(x: size.width / 2, y: size.height / 2)
            let originalCorner = anchor.position - halfSize
            let newCorner = newAnchorPos - halfSize
            let snappedNewCorner = controller.snap(newCorner)
            
            let cornerDelta = snappedNewCorner - originalCorner
            snappedNewAnchorPos = anchor.position + cornerDelta
        } else {
            // Snap the center of the object to the grid.
            snappedNewAnchorPos = controller.snap(newAnchorPos)
        }

        return snappedNewAnchorPos - anchor.position
    }

    // MARK: - End
    
    func end() {
        if didMove {
            // If a drag occurred, finalize the positions in the schematic graph.
            controller.schematicGraph.endDrag()
        }

        // Reset all transient state.
        origin = nil
        dragAnchor = nil
        originalElementPositions.removeAll()
        didMove = false
    }
}
