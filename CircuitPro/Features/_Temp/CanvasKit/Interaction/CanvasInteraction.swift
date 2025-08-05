//
//  CanvasInteraction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//


import AppKit

/// Defines a modular, self-contained interaction behavior for the canvas.
///
/// Each interaction can respond to mouse and keyboard events, and has access to the
/// full canvas state via the controller and render context. The CanvasView will
/// process an array of these interactions in order.
protocol CanvasInteraction {
    /// Responds to a mouse down event.
    /// - Returns: `true` if the event was handled and should not be passed to other interactions, `false` otherwise.
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool
    
    /// Responds to a mouse drag event.
    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController)
    
    /// Responds to a mouse up event.
    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController)
    
    // ... we can add keyDown, etc. as needed
}

// Provide default empty implementations so conformers only need to implement what they use.
extension CanvasInteraction {
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool { return false }
    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) { }
    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) { }
}