//
//  SelectionDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//  Refactored 17/07/25 – stripped connection-specific logic.
//

import AppKit

final class SelectionDragGesture: DragGesture {

    unowned let workbench: WorkbenchView

    private var origin: CGPoint?
    private var originalPositions: [UUID: CGPoint] = [:]
    private var didMove = false
    private let threshold: CGFloat = 4.0

    init(workbench: WorkbenchView) { self.workbench = workbench }

    // MARK: – Begin
    func begin(at p: CGPoint, event: NSEvent) -> Bool {
        let hitTarget = workbench.hitTestService.hitTest(
            at: p,
            elements: workbench.elements,
            schematicGraph: workbench.schematicGraph,
            magnification: workbench.magnification
        )

        // Drag starts only if the hit element is already selected.
        guard let hitTarget = hitTarget,
              let selectableID = hitTarget.selectableID,
              workbench.selectedIDs.contains(selectableID) else {
            return false
        }

        origin = p
        originalPositions.removeAll()

        // Cache original positions of selected canvas elements.
        for elt in workbench.elements where workbench.selectedIDs.contains(elt.id) {
            originalPositions[elt.id] = elt.transformable.position
        }


        return true
    }

    // MARK: – Drag
    func drag(to p: CGPoint) {
        guard let o = origin else { return }

        if !didMove && hypot(p.x - o.x, p.y - o.y) >= threshold {
            didMove = true
        }

        let delta = CGPoint(x: workbench.snapDelta(p.x - o.x),
                            y: workbench.snapDelta(p.y - o.y))

        // Move canvas elements
        var updatedElements = workbench.elements
        for i in updatedElements.indices {
            guard let base = originalPositions[updatedElements[i].id] else { continue }
            updatedElements[i].moveTo(originalPosition: base, offset: delta)
        }
        workbench.elements = updatedElements
        workbench.onUpdate?(updatedElements)


        workbench.connectionsView?.needsDisplay = true
    }

    // MARK: – End
    func end() {
        origin = nil
        originalPositions.removeAll()
        didMove = false
    }
}
