//
//  WorkbenchInputCoordinator.swift
//  CircuitPro
//
//  Fully refactored 17 Jul 25
//

import AppKit

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
    private var activeDrag: DragGesture?

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

        // Preview & live rotation
        rotation.update(to: p)
        workbench.previewView?.needsDisplay = true
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
            if let hitID = hitTest.hitTest(in: workbench.elements,
                                           at: p,
                                           magnification: workbench.magnification) {

                // An element was hit. Select it if not already selected.
                if !workbench.selectedIDs.contains(hitID) {
                    workbench.selectedIDs = [hitID]
                    workbench.onSelectionChange?(workbench.selectedIDs)
                }
            } else {
                // Empty space: clear selection and start marquee.
                if !workbench.selectedIDs.isEmpty {
                    workbench.selectedIDs.removeAll()
                    workbench.onSelectionChange?(workbench.selectedIDs)
                }
                marquee.begin(at: p)
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

        workbench.elementsView?.needsDisplay = true
        workbench.handlesView?.needsDisplay  = true
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
        case .connection:
            // TODO: Handle connection element creation
            break
        case .noResult:
            break
        }
        workbench.selectedTool = tool
    }

    func deleteSelectedElements() {
        guard !workbench.selectedIDs.isEmpty else { return }
        workbench.elements.removeAll { workbench.selectedIDs.contains($0.id) }
        workbench.selectedIDs.removeAll()
        workbench.onSelectionChange?(workbench.selectedIDs)
        workbench.onUpdate?(workbench.elements)
    }

    // MARK: – Public reset
    func reset() {
        marquee.end()
        activeDrag?.end()
        activeDrag = nil
        rotation.cancel()
    }
}
