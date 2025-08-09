//
//  RenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/4/25.
//

import AppKit

/// Defines a single, composable layer of rendering for the canvas.
/// Each rendering component conforms to this protocol. It is Hashable,
/// using its class type as its unique identifier.
protocol RenderLayer: AnyObject, Hashable {
    
    /// Called once to create and install the permanent CALayer(s) for this renderer.
    func install(on hostLayer: CALayer)
    
    /// Called on every redraw cycle to update the properties of the layers.
    func update(using context: RenderContext)

    /// Performs a hit-test on the content managed by this layer.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget?
}

// MARK: - Default Implementations & Conformance

extension RenderLayer {
    
    // Default implementation makes hit-testing optional for purely visual layers.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }
    
    // --- THIS IS THE FIX ---
    // This static function provides the required `Equatable` conformance for any
    // class that adopts the `RenderLayer` protocol.
    static func == (lhs: Self, rhs: Self) -> Bool {
        // This function is only called when the compiler already knows that `lhs` and `rhs`
        // are of the same concrete type (e.g., both are `GridRenderLayer`).
        // By our definition of type-based identity, two instances of the same class
        // are always considered equal.
        return true
    }
    
    // The `Hashable` conformance relies on the type's identity.
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type(of: self)))
    }
}
