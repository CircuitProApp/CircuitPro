//
//  CanvasRenderableProvider.swift
//  CircuitPro
//
//  Created by Codex on 12/29/25.
//

import AppKit

/// A render provider that renders items conforming to CanvasRenderable protocol.
/// This enables direct model rendering without intermediate graph components.
struct CanvasRenderableProvider: GraphRenderProvider {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?:
        [DrawingPrimitive]]
    {
        var result: [UUID?: [DrawingPrimitive]] = [:]

        for item in context.environment.renderables {
            let primitives = item.primitivesByLayer(in: context)
            for (layerId, layerPrimitives) in primitives {
                result[layerId, default: []].append(contentsOf: layerPrimitives)
            }
        }

        return result
    }
}

/// A halo provider that renders halos for items conforming to CanvasRenderable protocol.
struct CanvasRenderableHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>)
        -> [UUID?: [DrawingPrimitive]]
    {
        var result: [UUID?: [DrawingPrimitive]] = [:]

        for item in context.environment.renderables {
            guard highlightedIDs.contains(item.id) else { continue }
            guard let haloPath = item.haloPath() else { continue }

            let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            let haloPrimitive = DrawingPrimitive.stroke(
                path: haloPath,
                color: haloColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )
            result[nil, default: []].append(haloPrimitive)
        }

        return result
    }
}

/// A hit test provider for items conforming to CanvasRenderable protocol.
struct CanvasRenderableHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext)
        -> GraphHitCandidate?
    {
        var best: GraphHitCandidate?

        for item in context.environment.renderables {
            guard item.hitTest(point: point, tolerance: tolerance) else { continue }

            let bounds = item.renderBounds
            let area = bounds.width * bounds.height
            let candidate = GraphHitCandidate(id: NodeID(item.id), priority: 1, area: area)

            if let current = best {
                if candidate.priority > current.priority
                    || (candidate.priority == current.priority && candidate.area < current.area)
                {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }

        return best
    }

    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [NodeID] {
        var hits: [NodeID] = []

        for item in context.environment.renderables {
            if rect.intersects(item.renderBounds) {
                hits.append(NodeID(item.id))
            }
        }

        return hits
    }
}
