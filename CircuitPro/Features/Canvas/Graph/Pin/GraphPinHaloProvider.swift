//
//  GraphPinHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphPinHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (id, component) in graph.components(GraphPinComponent.self) {
            guard highlightedIDs.contains(id.rawValue) else { continue }
            if let ownerID = component.ownerID, highlightedIDs.contains(ownerID) {
                continue
            }
            guard let haloPath = component.pin.makeHaloPath() else { continue }

            let haloPrimitive = DrawingPrimitive.stroke(
                path: haloPath,
                color: NSColor.systemBlue.withAlphaComponent(0.4).cgColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )

            var transform = component.worldTransform
            let worldPrimitive = haloPrimitive.applying(transform: &transform)
            primitivesByLayer[component.layerId, default: []].append(worldPrimitive)
        }

        return primitivesByLayer
    }
}
