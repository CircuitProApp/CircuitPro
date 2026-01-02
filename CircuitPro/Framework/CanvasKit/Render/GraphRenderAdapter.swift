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

        for (_, item) in graph.allComponentsConforming(Drawable.self) {
            let primitives = item.makeDrawingPrimitives(in: context)
            for layered in primitives {
                primitivesByLayer[layered.layerId, default: []].append(layered.primitive)
            }
        }

        return primitivesByLayer
    }
}

extension GraphRenderAdapter: GraphRenderProvider {}
