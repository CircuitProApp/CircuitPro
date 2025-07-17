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
            netlist: workbench.netlist,
            magnification: workbench.magnification
        )

        // Drag starts only if the hit element is already selected.
        guard let hitTarget = hitTarget, workbench.selectedIDs.contains(hitTarget.selectableID) else {
            return false
        }

        origin = p
        originalPositions.removeAll()

        // Cache original positions of selected canvas elements.
        for elt in workbench.elements where workbench.selectedIDs.contains(elt.id) {
            originalPositions[elt.id] = elt.transformable.position
        }

        // Cache original positions of vertices in selected connections.
        for conn in workbench.netlist.connections where workbench.selectedIDs.contains(conn.id) {
            for vertex in conn.graph.vertices.values {
                originalPositions[vertex.id] = vertex.point
            }
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

        // Move connection vertices
        for conn in workbench.netlist.connections where workbench.selectedIDs.contains(conn.id) {
            for vertex in conn.graph.vertices.values {
                if let basePosition = originalPositions[vertex.id] {
                    vertex.point = basePosition + delta
                }
            }
        }
        workbench.connectionsView?.needsDisplay = true
    }

    // MARK: – End
    func end() {
        origin = nil
        originalPositions.removeAll()
        didMove = false
    }
}
