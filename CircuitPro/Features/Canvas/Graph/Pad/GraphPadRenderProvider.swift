//
//  GraphPadRenderProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphPadRenderProvider: GraphRenderProvider {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (_, component) in graph.components(CanvasPad.self) {
            let localPath = component.pad.calculateCompositePath()
            guard !localPath.isEmpty else { continue }

            let copperColor = NSColor.systemRed.cgColor
            let primitive = DrawingPrimitive.fill(path: localPath, color: copperColor)
            var transform = component.worldTransform
            let worldPrimitive = primitive.applying(transform: &transform)
            primitivesByLayer[component.layerId, default: []].append(worldPrimitive)
        }

        return primitivesByLayer
    }
}
