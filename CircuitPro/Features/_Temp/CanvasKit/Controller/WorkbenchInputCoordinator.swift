import AppKit

/// A lean input router that passes events to a pluggable list of interactions.
/// This class has no application-specific logic. It is a simple event forwarder.
final class WorkbenchInputCoordinator {

    // It only needs a reference to the controller, the source of truth.
    unowned let controller: CanvasController

    init(controller: CanvasController) {
        self.controller = controller
    }
    
    // MARK: - Event Routing
    
    // The host view is now passed into each method.
    func mouseDown(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds)
        let point = host.convert(event.locationInWindow, from: nil)

        for interaction in controller.interactions {
            if interaction.mouseDown(at: point, context: context, controller: controller) {
                controller.redraw()
                return // Event consumed.
            }
        }
        controller.redraw()
    }

    func mouseDragged(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds)
        let point = host.convert(event.locationInWindow, from: nil)
        
        for interaction in controller.interactions {
            interaction.mouseDragged(to: point, context: context, controller: controller)
        }
        controller.redraw()
    }

    func mouseUp(_ event: NSEvent, in host: CanvasHostView) {
        let context = controller.currentContext(for: host.bounds)
        let point = host.convert(event.locationInWindow, from: nil)

        for interaction in controller.interactions {
            interaction.mouseUp(at: point, context: context, controller: controller)
        }
        controller.redraw()
    }
    
    // MARK: - Passthrough Events
    
    func mouseMoved(_ event: NSEvent, in host: CanvasHostView) {
        controller.mouseLocation = host.convert(event.locationInWindow, from: nil)
        controller.redraw()
    }

    func mouseExited() {
        controller.mouseLocation = nil
        controller.redraw()
    }
}
