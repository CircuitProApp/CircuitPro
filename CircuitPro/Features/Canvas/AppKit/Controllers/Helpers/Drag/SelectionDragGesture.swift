//
//  SelectionDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//

import AppKit

final class SelectionDragGesture: CanvasDragGesture {

    unowned let workbench: WorkbenchView

    private var origin: CGPoint?
    private var didMove = false
    private let threshold: CGFloat = 4.0

    // Caches for original positions of items being dragged
    private var originalElementPositions: [UUID: CGPoint] = [:]
    private var originalTextPositions: [UUID: CGPoint] = [:]

    /// The starting position and size of the specific item that was hit by the cursor.
    /// This serves as the anchor point for grid-snapping calculations, ensuring
    /// that dragging an off-grid item onto a new grid works predictably.
    private var dragAnchor: (position: CGPoint, size: CGSize?, snapsToCenter: Bool)?

    init(workbench: WorkbenchView) { self.workbench = workbench }

    func begin(at point: CGPoint, event: NSEvent) -> Bool {
        let hitTarget = workbench.hitTestService.hitTest(
            at: point,
            elements: workbench.elements,
            schematicGraph: workbench.schematicGraph,
            magnification: workbench.magnification
        )

        guard let hitTarget = hitTarget else { return false }

        // An item is draggable if any part of its ownership chain is in the selection set.
        let isDraggable = hitTarget.ownerPath.contains { workbench.selectedIDs.contains($0) }
        guard isDraggable else {
            return false
        }

        // Set the anchor point for the drag. This is the starting position of the
        // item actually hit by the cursor, which allows for correct grid snapping
        // even if the item itself is currently off-grid.
        if let hitID = hitTarget.selectableID {
            if let element = workbench.elements.first(where: { $0.id == hitID }) {
                let position = element.transformable.position
                let size = element.primitive?.size
                // Default to center snapping for non-primitive elements.
                let snapsToCenter = element.primitive?.snapsToCenter ?? true
                dragAnchor = (position, size, snapsToCenter)
            } else {
                for element in workbench.elements {
                    if case .symbol(let symbol) = element {
                        for text in symbol.anchoredTexts {
                            // THIS LOGIC IS NOW CORRECT!
                            // `workbench.selectedIDs` contains the unique `AnchoredTextElement.id`.
                            // `text.id` is now also that unique ID.
                            // Therefore, this check will only be true for the one specific text element that was selected.
                            if workbench.selectedIDs.contains(text.id) {
                                // The key for the dictionary is the unique ID. The bug is fixed.
                                originalTextPositions[text.id] = text.position
                            }
                        }
                    }
                }
            }
        }

        origin = point
        originalElementPositions.removeAll()
        originalTextPositions.removeAll()
        didMove = false

        // Cache positions of all selected items.
        for element in workbench.elements {
            // If the whole element is selected, cache its position and skip checking children.
            if workbench.selectedIDs.contains(element.id) {
                originalElementPositions[element.id] = element.transformable.position
                continue
            }

            // If the element is not selected, check if it's a symbol with selected texts.
            if case .symbol(let symbol) = element {
                for text in symbol.anchoredTexts
                where workbench.selectedIDs.contains(text.id) {
                    originalTextPositions[text.id] = text.position
                }
            }
        }

        // Tell the schematic graph to prepare for a drag
        workbench.schematicGraph.beginDrag(selectedIDs: workbench.selectedIDs)

        return true
    }

    // MARK: – Drag
    func drag(to point: CGPoint) {
        guard let origin else { return }

        let rawDelta = point - origin

        if !didMove && hypot(rawDelta.x, rawDelta.y) < threshold {
            return
        }
        didMove = true

        // Calculates the move delta by first determining
        // the anchor item's ideal new position, snapping that to the grid, and
        // then calculating a delta from the anchor's original position. This
        // ensures the entire selection moves correctly onto the new grid.
        let moveDelta: CGPoint
        if let anchor = dragAnchor {
            let newAnchorPos = anchor.position + rawDelta
            let snappedNewAnchorPos: CGPoint

            // Use corner-snapping for rectangles, and center-snapping for everything else.
            if let size = anchor.size, size != .zero, !anchor.snapsToCenter {
                let halfSize = CGPoint(x: size.width / 2, y: size.height / 2)
                let originalCorner = anchor.position - halfSize
                let newCorner = newAnchorPos - halfSize
                let snappedNewCorner = workbench.snap(newCorner)

                let cornerDelta = snappedNewCorner - originalCorner
                snappedNewAnchorPos = anchor.position + cornerDelta
            } else {
                snappedNewAnchorPos = workbench.snap(newAnchorPos)
            }

            moveDelta = snappedNewAnchorPos - anchor.position
        } else {
            // Fallback to the old method if no anchor was set (should not happen in normal flow).
            moveDelta = CGPoint(x: workbench.snapDelta(rawDelta.x), y: workbench.snapDelta(rawDelta.y))
        }

        // Part 1: Move all selected elements (top-level and nested)
        if !originalElementPositions.isEmpty || !originalTextPositions.isEmpty {
            var updatedElements = workbench.elements
            for i in updatedElements.indices {

                // Case A: The whole element is selected, so move it.
                if let basePosition = originalElementPositions[updatedElements[i].id] {
                    updatedElements[i].moveTo(originalPosition: basePosition, offset: moveDelta)
                    // No need to check children, as they move with the parent.
                    continue
                }

                // Case B: The element is not selected, but might contain selected texts.
                if case .symbol(var symbol) = updatedElements[i] {
                    var wasModified = false
                    for j in symbol.anchoredTexts.indices {
                        let textID = symbol.anchoredTexts[j].id
                        if let basePosition = originalTextPositions[textID] {
                            let newPosition = basePosition + moveDelta
                            symbol.anchoredTexts[j].position = newPosition
                            wasModified = true
                        }
                    }
                    if wasModified {
                        // If any text was moved, the symbol struct has been changed,
                        // so we need to put the modified version back into the array.
                        updatedElements[i] = .symbol(symbol)
                    }
                }
            }
            workbench.elements = updatedElements
            workbench.onUpdate?(updatedElements)
        }

        // Part 2: Update the schematic drag
        workbench.schematicGraph.updateDrag(by: moveDelta)
    }

    // MARK: – End
    func end() {
        if didMove {
            workbench.schematicGraph.endDrag()
        }

        origin = nil
        dragAnchor = nil
        originalElementPositions.removeAll()
        originalTextPositions.removeAll()
        didMove = false
    }
}
