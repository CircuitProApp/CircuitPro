//
//  HandleDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//

import AppKit

final class HandleDragGesture: DragGesture {

    unowned let workbench: WorkbenchView
    private var active: (UUID, Handle.Kind)?
    private var frozenOppositeWorld: CGPoint?

    init(workbench: WorkbenchView) { self.workbench = workbench }

    func begin(at p: CGPoint, event: NSEvent) -> Bool {
        guard workbench.selectedIDs.count == 1 else { return false }
        let tol = 8.0 / workbench.magnification

        for element in workbench.elements
        where workbench.selectedIDs.contains(element.id) && element.isPrimitiveEditable {
            for h in element.handles()
            where hypot(p.x - h.position.x, p.y - h.position.y) < tol {
                active = (element.id, h.kind)
                if let opp = h.kind.opposite,
                   let other = element.handles().first(where: { $0.kind == opp }) {
                    frozenOppositeWorld = other.position
                }
                return true
            }
        }
        return false
    }

    func drag(to p: CGPoint) {
        guard let (id, kind) = active else { return }
        var updated = workbench.elements
        let snapped = workbench.snap(p)
        
        for i in updated.indices where updated[i].id == id {
            updated[i].updateHandle(kind, to: snapped, opposite: frozenOppositeWorld)
            workbench.elements = updated
            workbench.onUpdate?(updated)
            return
        }
    }

    func end() {
        active               = nil
        frozenOppositeWorld  = nil
    }
}
