//
//  RotationGestureController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//

import AppKit

/// Tracks a mouse-based rotation gesture for the current selection.
final class RotationGestureController {

    unowned let workbench: WorkbenchView

    private var origin: CGPoint?
    private var isActive = false

    init(workbench: WorkbenchView) {
        self.workbench = workbench
    }

    // starts a new gesture (invoked from the “R” key shortcut)
    func begin(at point: CGPoint) {
        origin = point
        isActive = true
    }

    // cancels the gesture (Esc pressed or second R tap)
    func cancel() {
        origin   = nil
        isActive = false
    }

    // called from mouse-move to update the angle
    func update(to cursor: CGPoint) {
        guard isActive, let origin else { return }

        var angle = atan2(cursor.y - origin.y, cursor.x - origin.x)

        if !NSEvent.modifierFlags.contains(.shift) {
            let step: CGFloat = .pi / 12 // 15 °
            angle = round(angle / step) * step
        }

        var updated = workbench.elements
        for i in updated.indices where workbench.selectedIDs.contains(updated[i].id) {
            updated[i].setRotation(angle)
        }
        workbench.elements = updated
        workbench.onUpdate?(updated)
    }

    var active: Bool { isActive }
}
