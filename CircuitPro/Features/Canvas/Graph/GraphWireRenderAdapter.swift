//
//  GraphWireRenderAdapter.swift
//  CircuitPro
//
//  Created by Codex on 9/21/25.
//

import AppKit

struct GraphWireRenderAdapter {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?:
        [DrawingPrimitive]]
    {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        for (_, edge) in graph.edgeComponents(WireEdgeComponent.self) {
            let path = CGMutablePath()
            path.move(to: edge.startPoint)
            path.addLine(to: edge.endPoint)

            let primitive = DrawingPrimitive.stroke(
                path: path,
                color: NSColor.controlAccentColor.cgColor,
                lineWidth: edge.lineWidth,
                lineCap: .round
            )
            primitivesByLayer[edge.layerId, default: []].append(primitive)
        }

        return primitivesByLayer
    }
}

extension GraphWireRenderAdapter: GraphRenderProvider {}
