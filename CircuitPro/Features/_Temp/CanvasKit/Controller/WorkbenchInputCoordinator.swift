import AppKit

/// A lean input router that passes events to a pluggable list of interactions.
/// This class has no application-specific logic. It is a simple event forwarder.
final class WorkbenchInputCoordinator {

    unowned let host: CanvasHostView
    unowned let controller: CanvasController

    // A convenience accessor for the context provided by the host view.
    private var currentContext: RenderContext? { host.currentContext }

    init(host: CanvasHostView, controller: CanvasController) {
        self.host = host
        self.controller = controller
    }
    
    // MARK: - Event Routing
    
    func mouseDown(_ event: NSEvent) {
        
        guard let context = currentContext else {
            print("⚠️ Input event ignored: Canvas context not yet available.")
            return
        }
        
        
        let point = host.convert(event.locationInWindow, from: nil)
        
        // Offer the event to each interaction in order.
        // Stop as soon as one of them returns `true`, indicating it handled the event.
        for interaction in controller.interactions {
            if interaction.mouseDown(at: point, context: context, controller: controller) {
                controller.redraw()
                return // Event consumed.
            }
        }
        controller.redraw()
    }

    func mouseDragged(_ event: NSEvent) {
        
        guard let context = currentContext else {
            print("⚠️ Input event ignored: Canvas context not yet available.")
            return
        }
        let point = host.convert(event.locationInWindow, from: nil)
        // Drag events are sent to all interactions that might be in a dragged state.
        for interaction in controller.interactions {
            interaction.mouseDragged(to: point, context: context, controller: controller)
        }
        controller.redraw()
    }

    func mouseUp(_ event: NSEvent) {
        
        guard let context = currentContext else {
            print("⚠️ Input event ignored: Canvas context not yet available.")
            return
        }
        
        let point = host.convert(event.locationInWindow, from: nil)
        // Up events are also sent to all interactions to let them reset their state.
        for interaction in controller.interactions {
            interaction.mouseUp(at: point, context: context, controller: controller)
        }
        controller.redraw()
    }
    
    // MARK: - Passthrough Events
    
    func mouseMoved(_ event: NSEvent) {
        // The master mouse location is still useful for things like the crosshairs layer.
        let point = host.convert(event.locationInWindow, from: nil)
        controller.mouseLocation = point
        // A `mouseMoved` method could be added to the CanvasInteraction protocol if needed.
        controller.redraw()
    }

    func mouseExited() {
        controller.mouseLocation = nil
        controller.redraw()
    }
    
    // KeyDown, RightMouseDown etc. would be added here and in the protocol if needed.
}
