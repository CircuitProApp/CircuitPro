//
//  CanvasInputHandler.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit

/// A lean input router that runs mouse events through a processing pipeline
/// before passing them to a pluggable list of interactions.
final class CanvasInputHandler {

    unowned let controller: CanvasController

    init(controller: CanvasController) {
        self.controller = controller
    }
    
    /// Runs a given point through the controller's ordered pipeline of input processors.
    /// - Parameters:
    ///   - point: The raw input point from a mouse event.
    ///   - context: The current render context for the event.
    /// - Returns: The final, processed CGPoint.
    private func process(point: CGPoint, context: RenderContext) -> CGPoint {
        // Sequentially pass the point through each processor. The output of one
        // becomes the input to the next.
        return controller.inputProcessors.reduce(point) { currentPoint, processor in
            processor.process(point: currentPoint, context: context)
        }
    }
    
    // MARK: - Event Routing
    
    func mouseDown(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        
        // Calculate both the raw coordinate and the final processed coordinate once.
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        let processedPoint = process(point: rawPoint, context: context)

        for interaction in controller.interactions {
            // Choose which point to send based on the interaction's preference.
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint
            
            if interaction.mouseDown(at: pointToUse, context: context, controller: controller) {
                controller.redraw()
                return // Event consumed.
            }
        }
        controller.redraw()
    }

    func mouseDragged(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)

        // Calculate both points once.
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        let processedPoint = process(point: rawPoint, context: context)
        
        for interaction in controller.interactions {
            // Choose which point to send based on the interaction's preference.
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint

            interaction.mouseDragged(to: pointToUse, context: context, controller: controller)
        }
        controller.redraw()
    }

    func mouseUp(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)

        // Calculate both points once.
        let rawPoint = host.convert(event.locationInWindow, from: nil)
        let processedPoint = process(point: rawPoint, context: context)

        for interaction in controller.interactions {
            // Choose which point to send based on the interaction's preference.
            let pointToUse = interaction.wantsRawInput ? rawPoint : processedPoint

            interaction.mouseUp(at: pointToUse, context: context, controller: controller)
        }
        controller.redraw()
    }
    
    // MARK: - Passthrough Events
    
    func mouseMoved(_ event: NSEvent, in host: CanvasHostView) {
        // The controller's mouseLocation should always store the RAW mouse position.
        // Render layers that need a processed version (like a preview) can get it
        // from the context during their update pass.
        controller.mouseLocation = host.convert(event.locationInWindow, from: nil)
        controller.redraw()
    }

    func mouseExited() {
        controller.redraw()
    }
    
    func keyDown(_ event: NSEvent, in host: CanvasHostView) -> Bool {
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        
        for interaction in controller.interactions {
            if interaction.keyDown(with: event, context: context, controller: controller) {
                // The interaction handled the key.
                controller.redraw()
                return true // Report that the event WAS handled.
            }
        }
        
        // No interaction handled the key.
        return false // Report that the event was NOT handled.
    }
}
