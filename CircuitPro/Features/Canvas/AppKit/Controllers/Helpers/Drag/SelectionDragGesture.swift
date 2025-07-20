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
    private var originalPositions: [UUID: CGPoint] = [:] // For non-schematic elements
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

        guard let hitTarget = hitTarget,
              let selectableID = hitTarget.selectableID,
              workbench.selectedIDs.contains(selectableID) else {
            return false
        }

        origin = p
        originalPositions.removeAll()
        didMove = false

        // 1. Cache for standard elements
        for elt in workbench.elements where workbench.selectedIDs.contains(elt.id) {
            originalPositions[elt.id] = elt.transformable.position
        }

        // 2. Tell the schematic graph to prepare for a drag
        workbench.schematicGraph.beginDrag(selectedIDs: workbench.selectedIDs)
        
        return true
    }

    // MARK: – Drag
    func drag(to p: CGPoint) {
        guard let o = origin else { return }

        let rawDelta = CGPoint(x: p.x - o.x, y: p.y - o.y)

        if !didMove && hypot(rawDelta.x, rawDelta.y) < threshold {
            return
        }
        didMove = true
        
        var moveDelta = CGPoint(x: workbench.snapDelta(rawDelta.x),
                                y: workbench.snapDelta(rawDelta.y))

        if let sheetFrame = workbench.sheetView?.frame {
            for id in workbench.selectedIDs {
                if let originalPos = originalPositions[id],
                   let element = workbench.elements.first(where: { $0.id == id }) {
                    
                    let newPos = CGPoint(x: originalPos.x + moveDelta.x, y: originalPos.y + moveDelta.y)
                    let elementBounds = element.boundingBox
                    let newBounds = elementBounds.offsetBy(dx: newPos.x - element.transformable.position.x, dy: newPos.y - element.transformable.position.y)

                    if newBounds.minX < sheetFrame.minX {
                        moveDelta.x -= newBounds.minX - sheetFrame.minX
                    }
                    if newBounds.maxX > sheetFrame.maxX {
                        moveDelta.x -= newBounds.maxX - sheetFrame.maxX
                    }
                    if newBounds.minY < sheetFrame.minY {
                        moveDelta.y -= newBounds.minY - sheetFrame.minY
                    }
                    if newBounds.maxY > sheetFrame.maxY {
                        moveDelta.y -= newBounds.maxY - sheetFrame.maxY
                    }
                }
            }
        }

        // --- Part 1: Move standard canvas elements ---
        if !originalPositions.isEmpty {
            var updatedElements = workbench.elements
            for i in updatedElements.indices {
                guard let base = originalPositions[updatedElements[i].id] else { continue }
                updatedElements[i].moveTo(originalPosition: base, offset: moveDelta)
            }
            workbench.elements = updatedElements
            workbench.onUpdate?(updatedElements)
        }

        // --- Part 2: Update the schematic drag ---
        workbench.schematicGraph.updateDrag(by: moveDelta)
        
        workbench.connectionsView?.needsDisplay = true
    }

    // MARK: – End
    func end() {
        if didMove {
            workbench.schematicGraph.endDrag()
        }
        
        origin = nil
        originalPositions.removeAll()
        didMove = false
        
        workbench.connectionsView?.needsDisplay = true
    }
}
