//
//  CanvasDraggableInteraction.swift
//  CircuitPro
//
//  Created by Codex on 12/29/25.
//

import AppKit

/// Handles dragging CanvasDraggable items on the canvas.
/// This interaction works directly with model items that conform to CanvasDraggable protocol.
final class CanvasDraggableInteraction: CanvasInteraction {

    private struct DragState {
        let origin: CGPoint
        let items: [(item: any CanvasDraggable, originalPosition: CGPoint)]
        let connectionEngine: (any ConnectionEngine)?
    }

    private var state: DragState?
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0

    var wantsRawInput: Bool { true }

    func mouseDown(
        with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController
    ) -> Bool {
        guard controller.selectedTool is CursorTool else { return false }

        let selection = context.graph.selection
        guard !selection.isEmpty else { return false }

        // Find which draggable items are selected
        let selectedIDs = Set(selection.map { $0.rawValue })
        let draggables = context.environment.renderables.compactMap { $0 as? (any CanvasDraggable) }
        let selectedDraggables = draggables.filter { selectedIDs.contains($0.id) }

        guard !selectedDraggables.isEmpty else { return false }

        // Check if we hit one of the selected items
        var hitSelected = false
        for item in selectedDraggables {
            if item.hitTest(point: point, tolerance: 5.0) {
                hitSelected = true
                break
            }
        }
        guard hitSelected else { return false }

        // Start connection drag if applicable
        var activeConnectionEngine: (any ConnectionEngine)?
        if let connectionEngine = context.environment.connectionEngine {
            if connectionEngine.beginDrag(selectedIDs: selectedIDs) {
                activeConnectionEngine = connectionEngine
            }
        }

        // Store original positions
        let items = selectedDraggables.map { ($0, $0.worldPosition) }

        self.state = DragState(
            origin: point, items: items, connectionEngine: activeConnectionEngine)
        self.didMove = false
        return true
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard let state = self.state else { return }

        let rawDelta = CGVector(dx: point.x - state.origin.x, dy: point.y - state.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }

        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)

        // Move each item from its original position
        for (item, originalPosition) in state.items {
            let newPosition = CGPoint(
                x: originalPosition.x + deltaPoint.x, y: originalPosition.y + deltaPoint.y)
            let delta = CGPoint(
                x: newPosition.x - item.worldPosition.x, y: newPosition.y - item.worldPosition.y)
            item.move(by: delta)
        }

        // Update connection engine
        state.connectionEngine?.updateDrag(by: deltaPoint)
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        if let state = self.state {
            state.connectionEngine?.endDrag()
        }
        self.state = nil
        self.didMove = false
    }
}
