//
//  CanvasInputHandler.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit

/// A lean input router that receives raw AppKit events, processes them, and dispatches
/// to hit targets and global handlers. It delegates redraw decisions to those handlers.
final class CanvasInputHandler {

    unowned let controller: CanvasController
    private var hoveredTargetID: UUID?
    private var dragTarget: CanvasHitTarget?
    private var dragLastRawPoint: CGPoint?
    private var dragLastProcessedPoint: CGPoint?
    private var dragSessions: [UUID: CanvasDragSession] = [:]
    private var globalDragLastRawPoint: CGPoint?
    private var globalDragLastProcessedPoint: CGPoint?
    private var globalDragActive = false
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
            processor.process(
                point: currentPoint,
                context: context,
                environment: controller.environment
            )
        }
    }

    // MARK: - Event Routing

    func mouseDown(_ event: NSEvent, in host: CanvasHostView) {
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        controller.environment.mouseLocation = rawPoint
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let processedPoint = process(point: rawPoint, context: context)
        controller.environment.processedMouseLocation = processedPoint

        if let tool = controller.selectedTool, tool.handlesInput {
            let interactionContext = ToolInteractionContext(
                clickCount: event.clickCount,
                renderContext: context,
                environment: controller.environment
            )
            let result = tool.handleTap(at: processedPoint, context: interactionContext)
            switch result {
            case .noResult:
                host.requestLayerUpdate()
                return
            case .newItem(let item):
                if let itemsBinding = context.itemsBinding {
                    var items = itemsBinding.wrappedValue
                    items.append(item)
                    itemsBinding.wrappedValue = items
                    host.requestLayerUpdate()
                    return
                }
            }
        }

        globalDragActive = true
        globalDragLastRawPoint = rawPoint
        globalDragLastProcessedPoint = processedPoint
        controller.canvasDragHandlers.handle(
            .began(CanvasGlobalDragEvent(
                event: event,
                rawLocation: rawPoint,
                processedLocation: processedPoint,
                rawDelta: .zero,
                processedDelta: .zero
            )),
            context: context,
            controller: controller
        )

        if let target = context.hitTargets.hitTest(rawPoint) {
            if target.onDrag != nil || target.onTap != nil {
                pendingHitTarget = target
                pendingStartRawPoint = rawPoint
                pendingStartProcessedPoint = processedPoint
                return
            }
        }

    }

    func mouseDragged(_ event: NSEvent, in host: CanvasHostView) {
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        controller.environment.mouseLocation = rawPoint
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let processedPoint = process(point: rawPoint, context: context)
        controller.environment.processedMouseLocation = processedPoint

        var didInvokeDragHandler = false

        if let target = dragTarget, let onDrag = target.onDrag {
            let session = dragSessions[target.id] ?? {
                let session = CanvasDragSession()
                dragSessions[target.id] = session
                return session
            }()
            let lastRaw = dragLastRawPoint ?? rawPoint
            let lastProcessed = dragLastProcessedPoint ?? processedPoint
            let rawDelta = CGPoint(x: rawPoint.x - lastRaw.x, y: rawPoint.y - lastRaw.y)
            let processedDelta = CGPoint(x: processedPoint.x - lastProcessed.x, y: processedPoint.y - lastProcessed.y)
            dragLastRawPoint = rawPoint
            dragLastProcessedPoint = processedPoint
                onDrag(.changed(delta: CanvasDragDelta(
                    raw: rawDelta,
                    processed: processedDelta,
                    rawLocation: rawPoint,
                    processedLocation: processedPoint
                )), session)
            didInvokeDragHandler = true
        }

        if let target = pendingHitTarget, let onDrag = target.onDrag {
            let startRaw = pendingStartRawPoint ?? rawPoint
            let startProcessed = pendingStartProcessedPoint ?? processedPoint
            let dx = rawPoint.x - startRaw.x
            let dy = rawPoint.y - startRaw.y
            if hypot(dx, dy) >= dragThreshold {
                pendingHitTarget = nil
                dragTarget = target
                let session = dragSessions[target.id] ?? {
                    let session = CanvasDragSession()
                    dragSessions[target.id] = session
                    return session
                }()
                dragLastRawPoint = rawPoint
                dragLastProcessedPoint = processedPoint
                onDrag(.began, session)
                let rawDelta = CGPoint(x: rawPoint.x - startRaw.x, y: rawPoint.y - startRaw.y)
                let processedDelta = CGPoint(x: processedPoint.x - startProcessed.x, y: processedPoint.y - startProcessed.y)
                onDrag(.changed(delta: CanvasDragDelta(
                    raw: rawDelta,
                    processed: processedDelta,
                    rawLocation: rawPoint,
                    processedLocation: processedPoint
                )), session)
                didInvokeDragHandler = true
            }
        }

        if globalDragActive {
            let lastRaw = globalDragLastRawPoint ?? rawPoint
            let lastProcessed = globalDragLastProcessedPoint ?? processedPoint
            let rawDelta = CGPoint(x: rawPoint.x - lastRaw.x, y: rawPoint.y - lastRaw.y)
            let processedDelta = CGPoint(x: processedPoint.x - lastProcessed.x, y: processedPoint.y - lastProcessed.y)
            globalDragLastRawPoint = rawPoint
            globalDragLastProcessedPoint = processedPoint
            let contextForGlobal = didInvokeDragHandler
                ? controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
                : context
            controller.canvasDragHandlers.handle(
                .changed(CanvasGlobalDragEvent(
                    event: event,
                    rawLocation: rawPoint,
                    processedLocation: processedPoint,
                    rawDelta: rawDelta,
                    processedDelta: processedDelta
                )),
                context: contextForGlobal,
                controller: controller
            )
        }

        host.requestLayerUpdate()
    }

    func mouseUp(_ event: NSEvent, in host: CanvasHostView) {
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        controller.environment.mouseLocation = rawPoint
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let processedPoint = process(point: rawPoint, context: context)
        controller.environment.processedMouseLocation = processedPoint

        var didInvokeHandler = false

        if let target = dragTarget, let onDrag = target.onDrag {
            if let session = dragSessions[target.id] {
                onDrag(.ended, session)
                dragSessions[target.id] = nil
            } else {
                onDrag(.ended, CanvasDragSession())
            }
            dragTarget = nil
            dragLastRawPoint = nil
            dragLastProcessedPoint = nil
            didInvokeHandler = true
        }

        if let target = pendingHitTarget {
            pendingHitTarget = nil
            pendingStartRawPoint = nil
            pendingStartProcessedPoint = nil
            if let onTap = target.onTap {
                onTap()
                didInvokeHandler = true
            }
        }

        if globalDragActive {
            let lastRaw = globalDragLastRawPoint ?? rawPoint
            let lastProcessed = globalDragLastProcessedPoint ?? processedPoint
            let rawDelta = CGPoint(x: rawPoint.x - lastRaw.x, y: rawPoint.y - lastRaw.y)
            let processedDelta = CGPoint(x: processedPoint.x - lastProcessed.x, y: processedPoint.y - lastProcessed.y)
            let contextForGlobal = didInvokeHandler
                ? controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
                : context
            controller.canvasDragHandlers.handle(
                .ended(CanvasGlobalDragEvent(
                    event: event,
                    rawLocation: rawPoint,
                    processedLocation: processedPoint,
                    rawDelta: rawDelta,
                    processedDelta: processedDelta
                )),
                context: contextForGlobal,
                controller: controller
            )
            globalDragActive = false
            globalDragLastRawPoint = nil
            globalDragLastProcessedPoint = nil
        }

        host.requestLayerUpdate()
    }

    // MARK: - Passthrough Events

    func mouseMoved(_ event: NSEvent, in host: CanvasHostView) {
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        controller.environment.mouseLocation = rawPoint
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let processedPoint = process(point: rawPoint, context: context)
        controller.environment.processedMouseLocation = processedPoint

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

        host.requestLayerUpdate()
    }

    func mouseExited() {
        controller.environment.mouseLocation = nil
        controller.environment.processedMouseLocation = nil
        controller.setInteractionHighlight(itemIDs: [])
        controller.setInteractionLinkHighlight(linkIDs: [])
        globalDragActive = false
        globalDragLastRawPoint = nil
        globalDragLastProcessedPoint = nil
        if let prevID = hoveredTargetID,
           let previous = controller.environment.hitTargets.targets.first(where: { $0.id == prevID }) {
            previous.onHover?(false)
        }
        hoveredTargetID = nil
        pendingHitTarget = nil
        pendingStartRawPoint = nil
        pendingStartProcessedPoint = nil
        dragTarget = nil
        dragLastRawPoint = nil
        dragLastProcessedPoint = nil
        dragSessions.removeAll()
        controller.view?.requestLayerUpdate()
    }

    func keyDown(_ event: NSEvent, in host: CanvasHostView) -> Bool {
        return false // Event was not handled.
    }
}
