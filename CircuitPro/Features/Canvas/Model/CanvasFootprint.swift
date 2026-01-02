//
//  CanvasFootprint.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import AppKit
import CoreGraphics
import Foundation

/// A canvas-space representation of a footprint, used for rendering and interaction in the Layout Editor.
struct CanvasFootprint: LayeredDrawable, Bounded, HitTestable, HaloProviding, Transformable, HitTestPriorityProviding {

    var ownerID: UUID
    var footprint: FootprintInstance
    var primitives: [AnyCanvasPrimitive]

    init(
        ownerID: UUID,
        footprint: FootprintInstance,
        primitives: [AnyCanvasPrimitive]
    ) {
        self.ownerID = ownerID
        self.footprint = footprint
        self.primitives = primitives
    }

    // MARK: - LayeredDrawable

    var id: UUID { ownerID }

    var renderBounds: CGRect {
        guard let local = localInteractionBounds() else { return .null }
        return local.applying(ownerTransform)
    }

    var hitTestPriority: Int { 2 }

    var boundingBox: CGRect {
        renderBounds
    }

    func primitivesByLayer(in context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var result: [UUID?: [DrawingPrimitive]] = [:]
        let transform = ownerTransform

        for primitive in primitives {
            let color = resolveColor(for: primitive, in: context)
            let drawPrimitives = primitive.makeDrawingPrimitives(with: color)
            guard !drawPrimitives.isEmpty else { continue }

            var primTransform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            .concatenating(transform)

            let worldPrimitives = drawPrimitives.map { $0.applying(transform: &primTransform) }
            result[primitive.layerId, default: []].append(contentsOf: worldPrimitives)
        }

        return result
    }

    func haloPath() -> CGPath? {
        let compositePath = CGMutablePath()
        let transform = ownerTransform

        for primitive in primitives {
            guard let halo = primitive.makeHaloPath() else { continue }
            let primTransform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            .concatenating(transform)
            compositePath.addPath(halo, transform: primTransform)
        }

        return compositePath.isEmpty ? nil : compositePath
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        let inverse = ownerTransform.inverted()
        let localPoint = point.applying(inverse)

        for primitive in primitives {
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

    // MARK: - Helpers

    var position: CGPoint {
        get { footprint.position }
        set { footprint.position = newValue }
    }

    var rotation: CGFloat {
        get { footprint.rotation }
        set { footprint.rotation = newValue }
    }

    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
    }

    func localInteractionBounds() -> CGRect? {
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
        return combined.isNull ? nil : combined
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

extension CanvasFootprint: CanvasItem {}
