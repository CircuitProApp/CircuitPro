//
//  ComponentInstance+CanvasDrawing.swift
//  CircuitPro
//
//  Created by Codex on 12/29/25.
//

import AppKit

// MARK: - Canvas Drawing & Interaction

extension ComponentInstance: HitTestable, Transformable {

    var position: CGPoint {
        get { symbolInstance.position }
        set { symbolInstance.position = newValue }
    }

    var rotation: CGFloat {
        get { symbolInstance.rotation }
        set { symbolInstance.rotation = newValue }
    }

    var hitTestPriority: Int { 5 }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        guard let symbolDef = symbolInstance.definition else { return false }

        let position = symbolInstance.position
        let rotation = symbolInstance.rotation
        let ownerTransform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        // Quick bounds check
        let bounds = calculateWorldBounds(for: symbolDef.primitives)
        guard !bounds.isNull,
            bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        else {
            return false
        }

        // Check primitives
        let ownerInverse = ownerTransform.inverted()
        let localPoint = point.applying(ownerInverse)

        for primitive in symbolDef.primitives {
            let primTransform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            let primLocal = localPoint.applying(primTransform.inverted())
            if primitive.hitTest(primLocal, tolerance: tolerance) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - Private Helpers

    private func calculateWorldBounds(for primitives: [AnyCanvasPrimitive]) -> CGRect {
        let position = symbolInstance.position
        let rotation = symbolInstance.rotation
        let ownerTransform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        var combined = CGRect.null
        for primitive in primitives {
            var box = primitive.boundingBox
            let primTransform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            box = box.applying(primTransform)
            combined = combined.union(box)
        }

        return combined.isNull ? .null : combined.applying(ownerTransform)
    }

    private func resolveColor(for primitive: AnyCanvasPrimitive, in context: RenderContext)
        -> CGColor
    {
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

}

extension ComponentInstance: CanvasItem {}
