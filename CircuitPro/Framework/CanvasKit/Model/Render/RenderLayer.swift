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
}

// MARK: - Default Implementations & Conformance

extension RenderLayer {

    static func == (lhs: Self, rhs: Self) -> Bool {
        return true
    }

    // The `Hashable` conformance relies on the type's identity.
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type(of: self)))
    }
}
