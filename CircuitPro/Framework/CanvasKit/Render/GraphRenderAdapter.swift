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

        for (_, item) in graph.componentsConforming(LayeredDrawable.self) {
            let primitives = item.primitivesByLayer(in: context)
            for (layerId, list) in primitives {
                primitivesByLayer[layerId, default: []].append(contentsOf: list)
            }
        }

        return primitivesByLayer
    }
}

extension GraphRenderAdapter: GraphRenderProvider {}
