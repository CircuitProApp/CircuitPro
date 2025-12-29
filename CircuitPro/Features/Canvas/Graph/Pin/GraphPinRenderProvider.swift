//
//  GraphPinRenderProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphPinRenderProvider: GraphRenderProvider {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?:
        [DrawingPrimitive]]
    {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        let wireEngine = context.environment.connectionEngine as? WireEngine

        for (_, component) in graph.components(GraphPinComponent.self) {
            let localPrimitives = component.pin.makeDrawingPrimitives()
            if localPrimitives.isEmpty { continue }

            var transform = component.worldTransform
            let worldPrimitives = localPrimitives.map { $0.applying(transform: &transform) }
            primitivesByLayer[component.layerId, default: []].append(contentsOf: worldPrimitives)

            guard let wireEngine,
                let ownerID = component.ownerID,
                let vertexID = wireEngine.findVertex(ownedBy: ownerID, pinID: component.pin.id)
            else { continue }

            let wireCount = wireEngine.adjacency[vertexID]?.count ?? 0
            if wireCount > 1 {
                let dotPath = CGPath(
                    ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4), transform: nil)
                let dotPrimitive = DrawingPrimitive.fill(
                    path: dotPath, color: NSColor.controlAccentColor.cgColor)
                var dotTransform = component.worldTransform
                let worldDot = dotPrimitive.applying(transform: &dotTransform)
                primitivesByLayer[component.layerId, default: []].append(worldDot)
            }
        }

        return primitivesByLayer
    }
}
