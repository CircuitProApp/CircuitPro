//
//  WireGraphHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct WireGraphHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        let haloIDs = highlightedIDs

        let compositePath = CGMutablePath()

        for (id, edge) in graph.components(WireEdgeComponent.self) {
            guard haloIDs.contains(id.rawValue),
                  let start = graph.component(WireVertexComponent.self, for: edge.start),
                  let end = graph.component(WireVertexComponent.self, for: edge.end) else {
                continue
            }
            compositePath.move(to: start.point)
            compositePath.addLine(to: end.point)
        }

        guard !compositePath.isEmpty else { return primitivesByLayer }

        let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
        let haloPrimitive = DrawingPrimitive.stroke(
            path: compositePath,
            color: haloColor,
            lineWidth: 5.0,
            lineCap: .round,
            lineJoin: .round
        )
        primitivesByLayer[nil, default: []].append(haloPrimitive)

        return primitivesByLayer
    }
}
