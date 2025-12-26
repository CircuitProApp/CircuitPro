//
//  GraphRenderAdapter.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import AppKit

struct GraphRenderAdapter {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (_, primitive) in graph.components(AnyCanvasPrimitive.self) {
            let resolvedColor = resolveColor(for: primitive, in: context)
            let primitives = primitive.makeDrawingPrimitives(with: resolvedColor)

            if primitives.isEmpty { continue }
            var transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            let worldPrimitives = primitives.map { $0.applying(transform: &transform) }
            let layerId = primitive.layerId
            primitivesByLayer[layerId, default: []].append(contentsOf: worldPrimitives)
        }

        return primitivesByLayer
    }

    private func resolveColor(for primitive: AnyCanvasPrimitive, in context: RenderContext) -> CGColor {
        if let overrideColor = primitive.color?.cgColor {
            return overrideColor
        }
        if let layerId = primitive.layerId,
           let layer = context.layers.first(where: { $0.id == layerId }) {
            return layer.color
        }
        return NSColor.systemBlue.cgColor
    }
}

extension GraphRenderAdapter: GraphRenderProvider {}
