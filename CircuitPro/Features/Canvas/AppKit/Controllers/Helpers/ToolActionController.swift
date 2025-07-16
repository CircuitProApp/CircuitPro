//
//  ToolActionController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//

import AppKit

/// Executes the currently selected canvas tool on mouse-down.
/// Stateless: every call builds its own `CanvasToolContext`.
final class ToolActionController {

    unowned let workbench: WorkbenchView
    let hitTest: WorkbenchHitTestService

    init(workbench: WorkbenchView,
         hitTest:   WorkbenchHitTestService) {
        self.workbench = workbench
        self.hitTest   = hitTest
    }

    /// Returns `true` when the event was consumed.
    func handleMouseDown(at p: CGPoint, event: NSEvent) -> Bool {

        guard var tool = workbench.selectedTool,
              tool.id != "cursor" else { return false }

        let snapped = workbench.snap(p)

        var ctx = CanvasToolContext(
            existingPinCount: workbench.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 },
            existingPadCount: workbench.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 },
            selectedLayer:    workbench.selectedLayer,
            magnification:    workbench.magnification
        )

        if tool.id == "connection" {
            ctx.hitTarget = hitTest.hitTestForConnection(
                in:  workbench.elements,
                at:  snapped,
                magnification: workbench.magnification)
        }
        ctx.clickCount = event.clickCount

        if let elt = tool.handleTap(at: snapped, context: ctx) {
            workbench.elements.append(elt)
            if case .primitive(let prim) = elt {
                workbench.onPrimitiveAdded?(prim.id, ctx.selectedLayer)
            }
            workbench.onUpdate?(workbench.elements)
        }

        workbench.selectedTool = tool
        return true
    }
}
