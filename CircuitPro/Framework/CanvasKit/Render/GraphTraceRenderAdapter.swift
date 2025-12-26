//
//  GraphTraceRenderAdapter.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphTraceRenderAdapter {
    func primitivesByLayer(from graph: Graph, context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (_, edge) in graph.components(TraceEdgeComponent.self) {
            guard let start = graph.component(TraceVertexComponent.self, for: edge.start),
                  let end = graph.component(TraceVertexComponent.self, for: edge.end) else {
                continue
            }

            let path = CGMutablePath()
            path.move(to: start.point)
            path.addLine(to: end.point)

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
