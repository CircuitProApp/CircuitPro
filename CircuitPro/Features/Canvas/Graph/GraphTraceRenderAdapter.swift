//
//  GraphTraceRenderAdapter.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphTraceRenderAdapter {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (_, edge) in graph.edgeComponents(TraceEdgeComponent.self) {
            let path = CGMutablePath()
            path.move(to: edge.startPoint)
            path.addLine(to: edge.endPoint)

            let color = resolveColor(for: edge, in: context)
            let primitive = DrawingPrimitive.stroke(
                path: path,
                color: color,
                lineWidth: edge.width,
                lineCap: .round
            )

            primitivesByLayer[edge.layerId, default: []].append(primitive)
        }

        return primitivesByLayer
    }

    private func resolveColor(for edge: TraceEdgeComponent, in context: RenderContext) -> CGColor {
        if let layerId = edge.layerId,
           let layer = context.layers.first(where: { $0.id == layerId }) {
            return layer.color
        }
        return NSColor.systemBlue.cgColor
    }
}

extension GraphTraceRenderAdapter: GraphRenderProvider {}
