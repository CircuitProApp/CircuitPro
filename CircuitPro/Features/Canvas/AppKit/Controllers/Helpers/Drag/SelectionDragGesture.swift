//
//  SelectionDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//


import AppKit

final class SelectionDragGesture: DragGesture {

    unowned let workbench: WorkbenchView

    private var origin: CGPoint?
    private var originalPositions: [UUID: CGPoint] = [:]
    private var didMove = false
    private let threshold: CGFloat = 4.0

    init(workbench: WorkbenchView) { self.workbench = workbench }

    func begin(at p: CGPoint, event: NSEvent) -> Bool {

        // A drag starts only if the hit element was already selected.
        let hit = workbench.hitTestService
            .hitTest(in: workbench.elements,
                     at: p,
                     magnification: workbench.magnification)

        guard let id = hit, workbench.selectedIDs.contains(id) else { return false }

        origin = p

        for elt in workbench.elements where workbench.selectedIDs.contains(elt.id) {
            if case .connection = elt { continue }
            let pos: CGPoint
            if case .symbol(let s) = elt { pos = s.instance.position }
            else if let prim = elt.primitives.first { pos = prim.position }
            else { continue }
            originalPositions[elt.id] = pos
        }
        return true
    }

    func drag(to p: CGPoint) {
        guard let o = origin else { return }

        if !didMove && hypot(p.x - o.x, p.y - o.y) >= threshold { didMove = true }

        let delta = CGPoint(x: workbench.snapDelta(p.x - o.x),
                            y: workbench.snapDelta(p.y - o.y))

        var updated = workbench.elements
        for i in updated.indices {
            guard let base = originalPositions[updated[i].id] else { continue }
            if case .connection = updated[i] { continue }
            updated[i].moveTo(originalPosition: base, offset: delta)
        }
        workbench.elements = updated
        workbench.onUpdate?(updated)
    }

    func end() {
        origin = nil
        originalPositions.removeAll()
        didMove = false
    }
}