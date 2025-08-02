//
//  WorkbenchInputCoordinator.swift
//  CircuitPro
//
//  Fully refactored 17 Jul 25
//

import AppKit
import UniformTypeIdentifiers

final class WorkbenchInputCoordinator {

    // MARK: – Dependencies
    unowned let workbench: WorkbenchView
    let hitTest: WorkbenchHitTestService

    // MARK: – Gesture helpers
    private lazy var rotation = RotationGestureController(workbench: workbench)
    private lazy var marquee = MarqueeSelectionGesture(workbench: workbench)
    private lazy var handleDrag = HandleDragGesture(workbench: workbench)
    private lazy var selDrag = SelectionDragGesture(workbench: workbench)
    private lazy var toolTap = ToolActionController(workbench: workbench, hitTest: hitTest)
    private lazy var keyCmds = WorkbenchKeyCommandController(workbench: workbench, coordinator: self)

    /// The drag recogniser that currently owns the pointer, if any.
    private var activeDrag: CanvasDragGesture?

    // MARK: – Init
    init(
        workbench: WorkbenchView,
        hitTest: WorkbenchHitTestService
    ) {
        self.workbench = workbench
        self.hitTest   = hitTest
    }

    // MARK: – Exposed state
    var isRotating: Bool { rotation.active }

    // MARK: – Keyboard
    func keyDown(_ event: NSEvent) -> Bool { keyCmds.handle(event) }

    // MARK: – Mouse-move
    func mouseMoved(_ event: NSEvent) {
        let point = workbench.convert(event.locationInWindow, from: nil)

        // Cross-hairs & coordinate read-out
        let snapped = workbench.snap(point)
        workbench.crosshairsView?.location = snapped
        workbench.onMouseMoved?(snapped)

        // Live hit-testing for cursor feedback
        updateCursor(at: point)

        // Preview & live rotation
        rotation.update(to: point)
        workbench.previewView?.updateMouseLocation(to: point)
    }

    func mouseExited() {
        workbench.crosshairsView?.location = nil
    }

    // MARK: – Mouse-down
    func mouseDown(_ event: NSEvent) {

        // First, check for and cancel any active rotation gesture.
        if rotation.active {
            rotation.cancel()
            return
        }
        
        let point = workbench.convert(event.locationInWindow, from: nil)
        
        // If a tool other than the cursor is active, let it handle the tap first.
        if toolTap.handleMouseDown(at: point, event: event) {
            return
        }

        // Prioritize dragging a resize/edit handle, as it's the most specific interaction.
        if handleDrag.begin(at: point, event: event) {
            activeDrag = handleDrag
            return
        }

        // From here on, we assume the Cursor tool is active or no other tool consumed the event.
        if workbench.selectedTool?.id == "cursor" {
            
            let hitTarget = hitTest.hitTest(
                at: point,
                elements: workbench.elements,
                schematicGraph: workbench.schematicGraph,
                magnification: workbench.magnification
            )

            // --- Logic for when an item was hit ---
            if let hitTarget = hitTarget {
                
                // ---- THIS IS THE CRITICAL LOGIC THAT IS NOW FIXED ----
                // We determine the correct, unique ID to select.
                let idToSelect: UUID?
                if hitTarget.kind == .text {
                    // If text was hit, we get the `immediateOwnerID`.
                    // Because we updated `AnchoredTextElement.hitTest`, this is now GUARANTEED
                    // to be the unique canvas `id` of the specific `AnchoredTextElement`
                    // that was clicked, NOT the shared data model ID.
                    idToSelect = hitTarget.immediateOwnerID
                } else {
                    // For任何 else, get the top-level selectable ID.
                    idToSelect = hitTarget.selectableID
                }

                // Now, `hitID` is guaranteed to be unique for the clicked element.
                if let hitID = idToSelect {
                    // Handle standard selection logic (Shift key for additive selection).
                    if event.modifierFlags.contains(.shift) {
                        if workbench.selectedIDs.contains(hitID) {
                            workbench.selectedIDs.remove(hitID)
                        } else {
                            workbench.selectedIDs.insert(hitID)
                        }
                    } else {
                        // If not holding Shift, only select the clicked item if it's not
                        // already the sole selected item.
                        if !workbench.selectedIDs.contains(hitID) {
                            workbench.selectedIDs = [hitID]
                        }
                    }
                    // Notify the rest of the app about the selection change.
                    workbench.onSelectionChange?(workbench.selectedIDs)
                }
                // ---- END OF FIXED LOGIC ----

                // After updating the selection, we attempt to begin a drag.
                // This will now work correctly because `selectedIDs` contains unique IDs.
                if selDrag.begin(at: point, event: event) {
                    activeDrag = selDrag
                }

            } else {
                // --- Logic for when empty space was hit ---
                // Clear the current selection (if not shift-clicking) and start the marquee.
                clearSelectionAndStartMarquee(with: event)
            }

            // The cursor tool has handled the event.
            return
        }
    }

    private func clearSelectionAndStartMarquee(with event: NSEvent) {
        if !event.modifierFlags.contains(.shift) {
            if !workbench.selectedIDs.isEmpty {
                workbench.selectedIDs.removeAll()
                workbench.onSelectionChange?(workbench.selectedIDs)
            }
        }
        let point = workbench.convert(event.locationInWindow, from: nil)
        marquee.begin(at: point, event: event)
    }

    // MARK: – Mouse-dragged
    func mouseDragged(_ event: NSEvent) {
        let point = workbench.convert(event.locationInWindow, from: nil)

        if marquee.active { marquee.drag(to: point); return }
        activeDrag?.drag(to: point)
    }

    // MARK: – Mouse-up
    func mouseUp(_ event: NSEvent) {
        if marquee.active { marquee.end() }
        activeDrag?.end()
        activeDrag = nil
    }

    // MARK: - Right-click
    func rightMouseDown(_ event: NSEvent) {
        // Context menus should only appear when the cursor tool is active.
        guard workbench.selectedTool?.id == "cursor" else { return }

        let point = workbench.convert(event.locationInWindow, from: nil)

        // Hit test to find the element under the cursor
        let hitTarget = hitTest.hitTest(
            at: point,
            elements: workbench.elements,
            schematicGraph: workbench.schematicGraph,
            magnification: workbench.magnification
        )

        guard let hitTarget = hitTarget else {
            // No specific element was hit. We could show a canvas context menu here.
            return
        }

        // Determine the selectable ID from the hit target.
        let idToSelect: UUID?
        if hitTarget.kind == .text {
            idToSelect = hitTarget.immediateOwnerID
        } else {
            idToSelect = hitTarget.selectableID
        }

        guard let hitID = idToSelect else { return }

        // If the right-clicked item is not already in the current selection,
        // clear the selection and select only the clicked item.
        if !workbench.selectedIDs.contains(hitID) {
            workbench.selectedIDs = [hitID]
            workbench.onSelectionChange?(workbench.selectedIDs)
        }

        // Create and show the context menu.
        let menu = NSMenu()

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteMenuAction(_:)), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        if !menu.items.isEmpty {
            menu.popUp(positioning: nil, at: point, in: workbench)
        }
    }

    @objc private func deleteMenuAction(_ sender: Any) {
        deleteSelectedElements()
    }

    // MARK: – Called by the key-command helper
    func enterRotationMode(around point: CGPoint) { rotation.begin(at: point) }
    func cancelRotation() { rotation.cancel() }

    // MARK: – Helpers for key-commands
    func handleReturnKeyPress() {
        guard var tool = workbench.selectedTool else { return }

        // Generic “confirm” for any tool that supports it.
        let result = tool.handleReturn()
        switch result {
        case .element(let newElement):
            workbench.elements.append(newElement)
            workbench.onUpdate?(workbench.elements)
        case .schematicModified:
            break
        case .noResult:
            break
        }
        workbench.selectedTool = tool

    }

    func deleteSelectedElements() {
        guard !workbench.selectedIDs.isEmpty else { return }

        // Delete from both the schematic graph and the canvas elements.
        workbench.schematicGraph.delete(items: workbench.selectedIDs)
        workbench.elements.removeAll { workbench.selectedIDs.contains($0.id) }

        // Clear the selection and notify listeners.
        workbench.selectedIDs.removeAll()
        workbench.onSelectionChange?([])
        workbench.onUpdate?(workbench.elements)
    }

    // MARK: – Public reset
    func reset() {
        marquee.end()
        activeDrag?.end()
        activeDrag = nil
        rotation.cancel()
    }

    // MARK: - Private Helpers
    private func updateCursor(at point: CGPoint) {
        // Only change cursor when the select tool is active.
        guard workbench.selectedTool?.id == "cursor" else {
            NSCursor.arrow.set()
            return
        }

        let hitTarget = hitTest.hitTest(
            at: point,
            elements: workbench.elements,
            schematicGraph: workbench.schematicGraph,
            magnification: workbench.magnification
        )

        switch hitTarget?.kind {
        case .pin, .pad:
            NSCursor.crosshair.set()
        case .primitive:
            NSCursor.pointingHand.set()
        default:
            NSCursor.arrow.set()
        }
    }
}

// MARK: - NSDraggingDestination
extension WorkbenchInputCoordinator {
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadItem(withDataConformingToTypes: [UTType.transferableComponent.identifier]) {
            return .copy
        }
        return []
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadItem(withDataConformingToTypes: [UTType.transferableComponent.identifier]) {
            return .copy
        }
        return []
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard pasteboard.canReadItem(withDataConformingToTypes: [UTType.transferableComponent.identifier]) else {
            return false
        }

        guard let data = pasteboard.data(forType: .transferableComponent) else {
            return false
        }

        do {
            let component = try JSONDecoder().decode(TransferableComponent.self, from: data)
            let pointInView = workbench.convert(sender.draggingLocation, from: nil)

            workbench.onComponentDropped?(component, pointInView)
            workbench.window?.makeFirstResponder(workbench)

            return true

        } catch {
            print("Failed to decode TransferableComponent:", error)
            return false
        }
    }
}

extension NSPasteboard.PasteboardType {
    static let transferableComponent = NSPasteboard.PasteboardType(UTType.transferableComponent.identifier)
}
