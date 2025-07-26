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
    let      hitTest:  WorkbenchHitTestService

    // MARK: – Gesture helpers
    private lazy var rotation   = RotationGestureController(workbench: workbench)
    private lazy var marquee    = MarqueeSelectionGesture(workbench: workbench)
    private lazy var handleDrag = HandleDragGesture(workbench: workbench)
    private lazy var selDrag    = SelectionDragGesture(workbench: workbench)
    private lazy var toolTap    = ToolActionController(workbench: workbench,
                                                       hitTest:   hitTest)
    private lazy var keyCmds    = WorkbenchKeyCommandController(workbench: workbench,
                                                                coordinator: self)

    /// The drag recogniser that currently owns the pointer, if any.
    private var activeDrag: CanvasDragGesture?

    // MARK: – Init
    init(workbench: WorkbenchView,
         hitTest:   WorkbenchHitTestService) {
        self.workbench = workbench
        self.hitTest   = hitTest
    }

    // MARK: – Exposed state
    var isRotating: Bool { rotation.active }

    // MARK: – Keyboard
    func keyDown(_ e: NSEvent) -> Bool { keyCmds.handle(e) }

    // MARK: – Mouse-move
    func mouseMoved(_ e: NSEvent) {
        let p = workbench.convert(e.locationInWindow, from: nil)

        // Cross-hairs & coordinate read-out
        let snapped = workbench.snap(p)
        workbench.crosshairsView?.location = snapped
        workbench.onMouseMoved?(snapped)

        // Live hit-testing for cursor feedback
        updateCursor(at: p)

        // Preview & live rotation
        rotation.update(to: p)
        workbench.previewView?.updateMouseLocation(to: p)
    }

    func mouseExited() {
        workbench.crosshairsView?.location = nil
    }

    // MARK: – Mouse-down
    func mouseDown(_ e: NSEvent) {

        // 1 ─ cancel an in-progress rotation gesture
        if rotation.active { rotation.cancel(); return }

        let p = workbench.convert(e.locationInWindow, from: nil)

        // 2 ─ let the active drawing tool try to consume the click
        if toolTap.handleMouseDown(at: p, event: e) { return }

        // 3 ─ hit-test for selection / marquee
        if workbench.selectedTool?.id == "cursor" {
            let hitTarget = hitTest.hitTest(
                at: p,
                elements: workbench.elements,
                schematicGraph: workbench.schematicGraph,
                magnification: workbench.magnification
            )

            if let hitTarget = hitTarget, let hitID = hitTarget.selectableID {
                print("Hit test result: \(hitTarget.debugDescription)")

                if e.modifierFlags.contains(.shift) {
                    // Shift-click: Toggle selection for the hit element.
                    if workbench.selectedIDs.contains(hitID) {
                        workbench.selectedIDs.remove(hitID)
                    } else {
                        workbench.selectedIDs.insert(hitID)
                    }
                } else {
                    // Normal click: If the item isn't already selected, make it the sole selection.
                    // If it IS already selected, we do nothing, allowing a drag to begin.
                    if !workbench.selectedIDs.contains(hitID) {
                        workbench.selectedIDs = [hitID]
                    }
                }
                workbench.onSelectionChange?(workbench.selectedIDs)

            } else {
                // Empty space or a non-selectable element was hit.
                // Clear selection (if shift isn't held) and start marquee.
                if !e.modifierFlags.contains(.shift) {
                    if !workbench.selectedIDs.isEmpty {
                        workbench.selectedIDs.removeAll()
                        workbench.onSelectionChange?(workbench.selectedIDs)
                    }
                }
                marquee.begin(at: p, event: e)
                return
            }
        }

        // 4 ─ otherwise try handle-drag, then selection-drag
        if handleDrag.begin(at: p, event: e) {
            activeDrag = handleDrag
        } else if selDrag.begin(at: p, event: e) {
            activeDrag = selDrag
        }
    }

    // MARK: – Mouse-dragged
    func mouseDragged(_ e: NSEvent) {
        let p = workbench.convert(e.locationInWindow, from: nil)

        if marquee.active { marquee.drag(to: p); return }
        activeDrag?.drag(to: p)
    }

    // MARK: – Mouse-up
    func mouseUp(_ e: NSEvent) {

        if marquee.active { marquee.end() }
        activeDrag?.end()
        activeDrag = nil

    }

    // MARK: – Called by the key-command helper
    func enterRotationMode(around p: CGPoint) { rotation.begin(at: p) }
    func cancelRotation()                     { rotation.cancel()    }

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
        
        // Force a redraw of the connections.
        
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
