//
//  SelectionDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//  Refactored 17/07/25 – stripped connection-specific logic.
//

import AppKit

final class SelectionDragGesture: CanvasDragGesture {

    unowned let workbench: WorkbenchView

    private var origin: CGPoint?
    private var didMove = false
    private let threshold: CGFloat = 4.0

    // Caches for original positions of items being dragged
    private var originalElementPositions: [UUID: CGPoint] = [:]
    private var originalTextPositions:    [UUID: CGPoint] = [:]
    
    /// The starting position of the specific item that was hit by the cursor.
    /// This serves as the anchor point for grid-snapping calculations, ensuring
    /// that dragging an off-grid item onto a new grid works predictably.
    private var dragAnchor: CGPoint?

    init(workbench: WorkbenchView) { self.workbench = workbench }

    // MARK: – Begin
    func begin(at p: CGPoint, event: NSEvent) -> Bool {
        let hitTarget = workbench.hitTestService.hitTest(
            at: p,
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
                dragAnchor = element.transformable.position
            } else {
                for element in workbench.elements {
                    if case .symbol(let symbol) = element,
                       let text = symbol.anchoredTexts.first(where: { $0.id == hitID }) {
                        dragAnchor = text.position
                        break
                    }
                }
            }
        }

        origin = p
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
                for text in symbol.anchoredTexts {
                    if workbench.selectedIDs.contains(text.id) {
                        originalTextPositions[text.id] = text.position
                    }
                }
            }
        }

        // Tell the schematic graph to prepare for a drag
        workbench.schematicGraph.beginDrag(selectedIDs: workbench.selectedIDs)
        
        return true
    }

    // MARK: – Drag
    func drag(to p: CGPoint) {
        guard let o = origin else { return }

        let rawDelta = p - o

        if !didMove && hypot(rawDelta.x, rawDelta.y) < threshold {
            return
        }
        didMove = true
        
        // The old implementation snapped the delta directly, which caused issues
        // when an item's original position was not on the current grid.
        //
        // The new implementation calculates the move delta by first determining
        // the anchor item's ideal new position, snapping that to the grid, and
        // then calculating a delta from the anchor's original position. This
        // ensures the entire selection moves correctly onto the new grid.
        let moveDelta: CGPoint
        if let anchor = dragAnchor {
            let newAnchorPos = anchor + rawDelta
            let snappedNewAnchorPos = workbench.snap(newAnchorPos)
            moveDelta = snappedNewAnchorPos - anchor
        } else {
            // Fallback to the old method if no anchor was set (should not happen in normal flow).
            moveDelta = CGPoint(x: workbench.snapDelta(rawDelta.x),
                                y: workbench.snapDelta(rawDelta.y))
        }

        // --- Part 1: Move all selected elements (top-level and nested) ---
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

        // --- Part 2: Update the schematic drag ---
        workbench.schematicGraph.updateDrag(by: moveDelta)
    }

    // MARK: – End
    func end() {
        if didMove {
            // Commit any movements to the underlying data model.
            commitTextMovement()
            workbench.schematicGraph.endDrag()
        }
        
        origin = nil
        dragAnchor = nil
        originalElementPositions.removeAll()
        originalTextPositions.removeAll()
        didMove = false
    }

    /// After a drag, this method persists the new positions of any moved
    /// anchored text elements back into the symbol's instance data model.
    /// This prevents the text from snapping back to its old position on the next redraw.
    private func commitTextMovement() {
        guard !originalTextPositions.isEmpty else { return }

        var updatedElements = workbench.elements
        for i in updatedElements.indices {
            guard case .symbol(var symbol) = updatedElements[i] else { continue }

            let movedTextIDs = Set(symbol.anchoredTexts.map(\.id)).intersection(originalTextPositions.keys)
            guard !movedTextIDs.isEmpty else { continue }

            // To modify the instance data, we follow the established pattern of creating a mutable copy.
            let newInstance = symbol.instance.copy()

            for textID in movedTextIDs {
                guard let text = symbol.anchoredTexts.first(where: { $0.id == textID }) else { continue }

                // Calculate the new position relative to the symbol's origin.
                let newRelativePosition = text.position.applying(symbol.transform.inverted())

                if text.isFromDefinition {
                    // This text is based on a library definition. We find its override and update it.
                    if let index = newInstance.anchoredTextOverrides.firstIndex(where: { $0.definitionID == text.sourceDataID }) {
                        newInstance.anchoredTextOverrides[index].relativePositionOverride = newRelativePosition
                    } else {
                        // If no override exists, we must create one.
                        let newOverride = AnchoredTextOverride(
                            definitionID: text.sourceDataID,
                            textOverride: text.textElement.text,
                            relativePositionOverride: newRelativePosition,
                            isVisible: true
                        )
                        newInstance.anchoredTextOverrides.append(newOverride)
                    }
                } else {
                    // This is an ad-hoc text added to the instance.
                    if let index = newInstance.adHocTexts.firstIndex(where: { $0.id == text.sourceDataID }) {
                        newInstance.adHocTexts[index].relativePosition = newRelativePosition
                    }
                }
            }
            
            // Assign the modified instance back to the symbol and update the element in the main array.
            symbol.instance = newInstance
            updatedElements[i] = .symbol(symbol)
        }

        workbench.elements = updatedElements
        workbench.onUpdate?(updatedElements)
    }
}
