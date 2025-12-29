//
//  CanvasRenderable.swift
//  CircuitPro
//
//  Created by Codex on 12/29/25.
//

import CoreGraphics
import Foundation

/// A protocol for objects that can be rendered on the canvas.
/// Conforming types provide drawing primitives and bounds for rendering and hit testing.
///
/// This protocol is domain-agnostic — it knows nothing about symbols, wires, etc.
/// CircuitPro implements this on its model types (ComponentInstance).
protocol CanvasRenderable: Identifiable where ID == UUID {

    /// The world-space bounding box for culling and hit testing.
    var renderBounds: CGRect { get }

    /// Generates drawing primitives for this element, grouped by layer.
    /// - Parameter context: The current render context with theme, viewport, etc.
    /// - Returns: A dictionary mapping layer IDs to drawing primitives.
    func primitivesByLayer(in context: RenderContext) -> [UUID?: [DrawingPrimitive]]

    /// Generates the halo path for selection highlight.
    /// - Returns: A path to stroke around the element when selected, or nil if no halo.
    func haloPath() -> CGPath?

    /// Hit tests this element at a point.
    /// - Parameters:
    ///   - point: The world-space point to test.
    ///   - tolerance: The hit test tolerance.
    /// - Returns: True if the point hits this element.
    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool
}

// MARK: - Default Implementations

extension CanvasRenderable {
    /// Default halo: nil (no halo)
    func haloPath() -> CGPath? { nil }

    /// Default hit test: bounds check
    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        renderBounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
    }
}
