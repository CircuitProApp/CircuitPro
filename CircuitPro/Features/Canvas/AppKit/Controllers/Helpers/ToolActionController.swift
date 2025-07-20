//
//  ToolActionController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import AppKit

/// Executes the currently selected canvas tool on mouse-down.
/// Stateless: every call builds its own `CanvasToolContext`.
final class ToolActionController {

    unowned let workbench: WorkbenchView
    let hitTest: WorkbenchHitTestService   // kept for future use

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
        
        // Perform a hit-test to create a rich context for the tool.
        let hitTarget = workbench.hitTestService.hitTest(
            at: snapped,
            elements: workbench.elements,
            schematicGraph: workbench.schematicGraph,
            magnification: workbench.magnification
        )

        var ctx = CanvasToolContext(
            existingPinCount: workbench.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 },
            existingPadCount: workbench.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 },
            selectedLayer:    workbench.selectedLayer,
            magnification:    workbench.magnification,
            hitTarget:        hitTarget,
            schematicGraph:   workbench.schematicGraph,
            clickCount:       event.clickCount
        )

        let result = tool.handleTap(at: snapped, context: ctx)

        switch result {
        case .element(let newElement):
            workbench.elements.append(newElement)
            if case .primitive(let prim) = newElement {
                workbench.onPrimitiveAdded?(prim.id, ctx.selectedLayer)
            }
            workbench.onUpdate?(workbench.elements)
        
        case .schematicModified:
            workbench.connectionsView?.needsDisplay = true
            
        case .noResult:
            break
        }

        workbench.selectedTool = tool
        return true
    }
}
