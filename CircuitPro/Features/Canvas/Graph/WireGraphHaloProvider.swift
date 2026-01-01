//
//  WireGraphHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct WireGraphHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<GraphElementID>) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        let compositePath = CGMutablePath()

        for (edgeID, edge) in graph.edgeComponents(WireEdgeComponent.self) {
            guard highlightedIDs.contains(.edge(edgeID)) else { continue }
            compositePath.move(to: edge.startPoint)
            compositePath.addLine(to: edge.endPoint)
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
