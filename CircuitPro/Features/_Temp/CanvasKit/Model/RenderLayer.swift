//
//  RenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/4/25.
//

import AppKit
/// Defines a single, composable layer of rendering for the canvas.
/// Each rendering component conforms to this protocol.
protocol RenderLayer {
    /// A unique key for debugging and layer identification.
    var layerKey: String { get }
    
    /// Called once to create the permanent CALayer(s) for this renderer and add them
    /// as sublayers to the host's main layer.
    func install(on hostLayer: CALayer)
    
    /// Called on every redraw to update the properties (e.g., path, color, isHidden)
    /// of the layers this renderer installed previously.
    func update(using context: RenderContext)

    /// Performs a hit-test to determine if a point intersects with any interactive
    /// content managed by this layer.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget?
}

// Default implementation makes hit-testing optional for layers that are not interactive.
extension RenderLayer {
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }
}
