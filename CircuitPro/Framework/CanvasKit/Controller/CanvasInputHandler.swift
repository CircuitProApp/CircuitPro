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

        for interaction in controller.interactions {
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            interaction.mouseUp(at: pointToUse, context: context, controller: controller)
        }

        host.performLayerUpdate()
    }
    
    // MARK: - Passthrough Events
    
    func mouseMoved(_ event: NSEvent, in host: CanvasHostView) {
        controller.mouseLocation = host.convert(event.locationInWindow, from: nil)
        host.performLayerUpdate()
    }

    func mouseExited() {
        controller.mouseLocation = nil
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
