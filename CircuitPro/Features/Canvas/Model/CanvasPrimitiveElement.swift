//
//  CanvasPrimitiveElement.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import AppKit
import CoreGraphics

/// A canvas-space representation of a graphic primitive (line, rect, etc.), used for rendering and interaction.
struct CanvasPrimitiveElement: Drawable, Bounded, HitTestable, Transformable, Layerable {

    var primitive: AnyCanvasPrimitive

    init(primitive: AnyCanvasPrimitive) {
        self.primitive = primitive
    }

    // MARK: - Drawable

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

    func makeDrawingPrimitives(in context: RenderContext) -> [LayeredDrawingPrimitive] {
        primitive.makeDrawingPrimitives(in: context)
    }

    func haloPath() -> CGPath? {
        primitive.haloPath()
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        let transform = CGAffineTransform(
            translationX: primitive.position.x, y: primitive.position.y
        )
        .rotated(by: primitive.rotation)
        let localPoint = point.applying(transform.inverted())
        return primitive.hitTest(localPoint, tolerance: tolerance) != nil
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

extension CanvasPrimitiveElement: CanvasItem {}
