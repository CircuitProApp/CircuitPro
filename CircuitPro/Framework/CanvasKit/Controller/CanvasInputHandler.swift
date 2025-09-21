//
//  CanvasInputHandler.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit

/// A lean input router that receives raw AppKit events, processes them, and passes
/// them to a pluggable list of interactions. It is also responsible for triggering
/// imperative redraws for events that only affect transient visual state.
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
        let processedPoint = process(point: rawPoint, context: context)

        // Update mouse location state
        controller.mouseLocation = rawPoint

        for interaction in controller.interactions {
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            if interaction.mouseDown(with: event, at: pointToUse, context: context, controller: controller) {
                return // Event consumed.
            }
        }
    }

    func mouseDragged(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        
        // Update mouse location state
        controller.mouseLocation = rawPoint
        
        let processedPoint = process(point: rawPoint, context: context)
        
        for interaction in controller.interactions {
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            interaction.mouseDragged(to: pointToUse, context: context, controller: controller)
        }
        
        // ** THE FIX **
        // After all interactions have processed the drag, force a redraw.
        // This is necessary for visuals like the marquee rectangle to update live.
        host.performLayerUpdate()
    }

    func mouseUp(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        
        // Update mouse location state
        controller.mouseLocation = rawPoint
        
        let processedPoint = process(point: rawPoint, context: context)

        for interaction in controller.interactions {
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            interaction.mouseUp(at: pointToUse, context: context, controller: controller)
        }
    }
    
    // MARK: - Passthrough Events
    
    func mouseMoved(_ event: NSEvent, in host: CanvasHostView) {
        // 1. Update the state on the controller.
        controller.mouseLocation = host.convert(event.locationInWindow, from: nil)
        
        // ** THE FIX **
        // 2. Imperatively trigger a redraw.
        // This is necessary because moving the mouse is a transient visual change
        // (for crosshairs, hover highlights, etc.) that does not change any
        // SwiftUI state, so `updateNSView` will not be called automatically.
        host.performLayerUpdate()
    }

    func mouseExited() {
        // When the mouse leaves, clear its location and redraw to ensure
        // crosshairs and other hover effects disappear correctly.
        controller.mouseLocation = nil
        controller.view?.performLayerUpdate()
    }
    
    func keyDown(_ event: NSEvent, in host: CanvasHostView) -> Bool {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        
        for interaction in controller.interactions {
            if interaction.keyDown(with: event, context: context, controller: controller) {
                return true // Event was handled.
            }
        }
        
        return false // Event was not handled.
    }
}
