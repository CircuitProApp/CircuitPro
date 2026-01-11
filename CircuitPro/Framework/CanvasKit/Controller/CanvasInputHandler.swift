//
//  CanvasInputHandler.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit

/// A lean input router that receives raw AppKit events, processes them, and passes
/// them to a pluggable list of interactions. It delegates the responsibility of
/// triggering imperative redraws to the interactions themselves.
final class CanvasInputHandler {

    unowned let controller: CanvasController
    private var hoveredTargetID: UUID?
    private var dragTarget: CanvasHitTarget?
    private var dragLastRawPoint: CGPoint?
    private var dragLastProcessedPoint: CGPoint?
    private var pendingHitTarget: CanvasHitTarget?
    private var pendingStartRawPoint: CGPoint?
    private var pendingStartProcessedPoint: CGPoint?
    private let dragThreshold: CGFloat = 3.0

    init(controller: CanvasController) {
        self.controller = controller
    }

    /// Runs a given point through the controller's ordered pipeline of input processors.
    private func process(point: CGPoint, context: RenderContext) -> CGPoint {
        return controller.inputProcessors.reduce(point) { currentPoint, processor in
            processor.process(point: currentPoint, context: context)
        }
    }

    // MARK: - Event Routing

    func mouseDown(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        controller.mouseLocation = rawPoint
        let processedPoint = process(point: rawPoint, context: context)

        if let target = context.hitTargets.hitTest(rawPoint) {
            if target.onDrag != nil || target.onTap != nil {
                pendingHitTarget = target
                pendingStartRawPoint = rawPoint
                pendingStartProcessedPoint = processedPoint
                return
            }
        }

        for interaction in controller.interactions {
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            if interaction.mouseDown(with: event, at: pointToUse, context: context, controller: controller) {
                host.performLayerUpdate()
                return
            }
        }
    }

    func mouseDragged(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        controller.mouseLocation = rawPoint
        let processedPoint = process(point: rawPoint, context: context)

        if let target = dragTarget, let onDrag = target.onDrag {
            let lastRaw = dragLastRawPoint ?? rawPoint
            let lastProcessed = dragLastProcessedPoint ?? processedPoint
            let rawDelta = CGPoint(x: rawPoint.x - lastRaw.x, y: rawPoint.y - lastRaw.y)
            let processedDelta = CGPoint(x: processedPoint.x - lastProcessed.x, y: processedPoint.y - lastProcessed.y)
            dragLastRawPoint = rawPoint
            dragLastProcessedPoint = processedPoint
            onDrag(.changed(delta: CanvasDragDelta(raw: rawDelta, processed: processedDelta)))
            host.performLayerUpdate()
            return
        }

        if let target = pendingHitTarget, let onDrag = target.onDrag {
            let startRaw = pendingStartRawPoint ?? rawPoint
            let startProcessed = pendingStartProcessedPoint ?? processedPoint
            let dx = rawPoint.x - startRaw.x
            let dy = rawPoint.y - startRaw.y
            if hypot(dx, dy) >= dragThreshold {
                pendingHitTarget = nil
                dragTarget = target
                dragLastRawPoint = rawPoint
                dragLastProcessedPoint = processedPoint
                onDrag(.began)
                let rawDelta = CGPoint(x: rawPoint.x - startRaw.x, y: rawPoint.y - startRaw.y)
                let processedDelta = CGPoint(x: processedPoint.x - startProcessed.x, y: processedPoint.y - startProcessed.y)
                onDrag(.changed(delta: CanvasDragDelta(raw: rawDelta, processed: processedDelta)))
                host.performLayerUpdate()
                return
            }
        }

        for interaction in controller.interactions {
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            interaction.mouseDragged(to: pointToUse, context: context, controller: controller)
        }

        host.performLayerUpdate()
    }

    func mouseUp(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        controller.mouseLocation = rawPoint
        let processedPoint = process(point: rawPoint, context: context)

        if let target = dragTarget, let onDrag = target.onDrag {
            onDrag(.ended)
            dragTarget = nil
            dragLastRawPoint = nil
            dragLastProcessedPoint = nil
            host.performLayerUpdate()
            return
        }

        if let target = pendingHitTarget {
            pendingHitTarget = nil
            pendingStartRawPoint = nil
            pendingStartProcessedPoint = nil
            if let onTap = target.onTap {
                onTap()
                host.performLayerUpdate()
                return
            }
        }

        for interaction in controller.interactions {
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            interaction.mouseUp(at: pointToUse, context: context, controller: controller)
        }

        host.performLayerUpdate()
    }

    // MARK: - Passthrough Events

    func mouseMoved(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        controller.mouseLocation = rawPoint
        let processedPoint = process(point: rawPoint, context: context)

        let hitTarget = context.hitTargets.hitTest(rawPoint)
        let hitID = hitTarget?.id
        if hitID != hoveredTargetID {
            if let prevID = hoveredTargetID,
               let previous = context.hitTargets.targets.first(where: { $0.id == prevID }) {
                previous.onHover?(false)
            }
            hoveredTargetID = hitID
            hitTarget?.onHover?(true)
        }

        for interaction in controller.interactions {
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            interaction.mouseMoved(at: pointToUse, context: context, controller: controller)
        }

        host.performLayerUpdate()
    }

    func mouseExited() {
        controller.mouseLocation = nil
        controller.setInteractionHighlight(itemIDs: [])
        controller.setInteractionLinkHighlight(linkIDs: [])
        if let prevID = hoveredTargetID,
           let previous = controller.hitTargets.targets.first(where: { $0.id == prevID }) {
            previous.onHover?(false)
        }
        hoveredTargetID = nil
        pendingHitTarget = nil
        pendingStartRawPoint = nil
        pendingStartProcessedPoint = nil
        dragTarget = nil
        dragLastRawPoint = nil
        dragLastProcessedPoint = nil
        controller.view?.performLayerUpdate()
    }

    func keyDown(_ event: NSEvent, in host: CanvasHostView) -> Bool {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)

        for interaction in controller.interactions {
            if interaction.keyDown(with: event, context: context, controller: controller) {
                host.performLayerUpdate()
                return true // Event was handled.
            }
        }

        return false // Event was not handled.
    }
}
