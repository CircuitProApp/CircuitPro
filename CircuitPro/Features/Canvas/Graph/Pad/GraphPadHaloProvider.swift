//
//  GraphPadHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphPadHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<GraphElementID>) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (id, component) in graph.components(GraphPadComponent.self) {
            guard highlightedIDs.contains(.node(id)) else { continue }
            if let ownerID = component.ownerID, highlightedIDs.contains(.node(NodeID(ownerID))) {
                continue
            }

            let haloWidth: CGFloat = 1.0
            let shapePath = component.pad.calculateShapePath()
            guard !shapePath.isEmpty else { continue }
            let thickOutline = shapePath.copy(strokingWithWidth: haloWidth * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
            let haloPath = thickOutline.union(shapePath)

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
