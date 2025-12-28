//
//  GraphTextHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphTextHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>)
        -> [UUID?: [DrawingPrimitive]]
    {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (id, component) in graph.components(GraphTextComponent.self) {
            guard highlightedIDs.contains(id.rawValue) else { continue }
            if highlightedIDs.contains(component.ownerID) {
                continue
            }
            guard component.isVisible else { continue }
            let worldPath = component.worldPath()
            guard !worldPath.isEmpty else { continue }

            let textColor = context.environment.canvasTheme.textColor
            let haloColor =
                NSColor(cgColor: textColor)?.withAlphaComponent(0.4).cgColor ?? textColor
            let haloPrimitive = DrawingPrimitive.stroke(
                path: worldPath,
                color: haloColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )

            primitivesByLayer[component.layerId, default: []].append(haloPrimitive)
        }

        return primitivesByLayer
    }
}
