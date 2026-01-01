//
//  CanvasPrimitiveElement.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import AppKit
import CoreGraphics

/// A canvas-space representation of a graphic primitive (line, rect, etc.), used for rendering and interaction.
final class CanvasPrimitiveElement: GraphComponent, LayeredDrawable, Bounded, HitTestable, HaloProviding, Transformable, Layerable, HitTestPriorityProviding {

    var primitive: AnyCanvasPrimitive

    init(primitive: AnyCanvasPrimitive) {
        self.primitive = primitive
    }

    // MARK: - LayeredDrawable

    var id: UUID { primitive.id }

    var layerId: UUID? {
        get { primitive.layerId }
        set { primitive.layerId = newValue }
    }

    var renderBounds: CGRect {
        primitive.boundingBox.applying(
            CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
        )
    }

    var hitTestPriority: Int { 1 }

    var boundingBox: CGRect {
        renderBounds
    }

    func primitivesByLayer(in context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        let color = resolveColor(in: context)
        let drawPrimitives = primitive.makeDrawingPrimitives(with: color)

        var transform = CGAffineTransform(
            translationX: primitive.position.x, y: primitive.position.y
        )
        .rotated(by: primitive.rotation)

        let worldPrimitives = drawPrimitives.map { $0.applying(transform: &transform) }
        return [primitive.layerId: worldPrimitives]
    }

    func haloPath() -> CGPath? {
        guard let localHalo = primitive.makeHaloPath() else { return nil }
        var transform = CGAffineTransform(
            translationX: primitive.position.x, y: primitive.position.y
        )
        .rotated(by: primitive.rotation)
        return localHalo.copy(using: &transform)
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        let transform = CGAffineTransform(
            translationX: primitive.position.x, y: primitive.position.y
        )
        .rotated(by: primitive.rotation)
        let localPoint = point.applying(transform.inverted())
        return primitive.hitTest(localPoint, tolerance: tolerance) != nil
    }

    private func resolveColor(in context: RenderContext) -> CGColor {
        if let overrideColor = primitive.color?.cgColor {
            return overrideColor
        }
        if let layerId = primitive.layerId,
            let layer = context.layers.first(where: { $0.id == layerId })
        {
            return layer.color
        }
        return NSColor.systemBlue.cgColor
    }

    // MARK: - Transformable

    var position: CGPoint {
        get {
            primitive.position
        }
        set {
            primitive.position = newValue
        }
    }

    var rotation: CGFloat {
        get { primitive.rotation }
        set { primitive.rotation = newValue }
    }
}
