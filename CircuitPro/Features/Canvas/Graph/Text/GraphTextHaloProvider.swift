//
//  GraphTextHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphTextHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (id, component) in graph.components(GraphTextComponent.self) {
            guard highlightedIDs.contains(id.rawValue) else { continue }
            guard component.isVisible else { continue }
            let worldPath = component.worldPath()
            guard !worldPath.isEmpty else { continue }

            let haloPrimitive = DrawingPrimitive.stroke(
                path: worldPath,
                color: NSColor.systemBlue.withAlphaComponent(0.4).cgColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )

            primitivesByLayer[component.layerId, default: []].append(haloPrimitive)
        }

        return primitivesByLayer
    }
}
