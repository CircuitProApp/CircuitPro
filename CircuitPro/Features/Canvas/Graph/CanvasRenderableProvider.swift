//
//  CanvasRenderableProvider.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import CoreGraphics
import Foundation

/// A bridge that allows the `CanvasGraph` to render elements that conform to `CanvasRenderable`.
/// This provider looks at both the graph components and the environment's `renderables`.
struct CanvasRenderableProvider: GraphRenderProvider {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?:
        [DrawingPrimitive]]
    {
        var result: [UUID?: [DrawingPrimitive]] = [:]

        // 1. Render items from the environment (e.g. Schematic Symbols)
        for renderable in context.environment.renderables {
            let primitives = renderable.primitivesByLayer(in: context)
            for (layerID, list) in primitives {
                result[layerID, default: []].append(contentsOf: list)
            }
        }

        // 2. Render items from the graph (e.g. Symbol Editor Pins, Primitives)
        // We look for anything in the graph that conforms to CanvasRenderable
        // (Note: Since components are stored as Any, we check each type that might conform)
        // In our refactored world, these are CanvasPin, CanvasText, CanvasPrimitiveElement.

        func append<T: CanvasRenderable>(_ type: T.Type) {
            for (_, component) in graph.components(type) {
                let primitives = component.primitivesByLayer(in: context)
                for (layerID, list) in primitives {
                    result[layerID, default: []].append(contentsOf: list)
                }
            }
        }

        append(CanvasPin.self)
        append(CanvasText.self)
        append(CanvasPrimitiveElement.self)

        return result
    }
}

/// A bridge for selection halos.
struct CanvasRenderableHaloProvider: GraphHaloProvider {
    func haloPath(for id: NodeID, graph: CanvasGraph, context: RenderContext) -> CGPath? {
        // 1. Check graph components
        if let renderable = graph.component(CanvasPin.self, for: id) {
            return renderable.haloPath()
        }
        if let renderable = graph.component(CanvasText.self, for: id) {
            return renderable.haloPath()
        }
        if let renderable = graph.component(CanvasPrimitiveElement.self, for: id) {
            return renderable.haloPath()
        }

        // 2. Check environment renderables
        if let renderable = context.environment.renderables.first(where: { $0.id == id.rawValue }) {
            return renderable.haloPath()
        }

        return nil
    }
}

/// A bridge for hit testing.
struct CanvasRenderableHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext)
        -> GraphHitCandidate?
    {
        var best: GraphHitCandidate?

        func check<T: CanvasRenderable>(_ type: T.Type, priority: Int) {
            for (id, renderable) in graph.components(type) {
                if renderable.hitTest(point: point, tolerance: tolerance) {
                    let area = renderable.renderBounds.width * renderable.renderBounds.height
                    let candidate = GraphHitCandidate(id: id, priority: priority, area: area)
                    if best == nil || candidate.priority > best!.priority
                        || (candidate.priority == best!.priority && candidate.area < best!.area)
                    {
                        best = candidate
                    }
                }
            }
        }

        // Higher priority for pins and text
        check(CanvasPin.self, priority: 10)
        check(CanvasText.self, priority: 5)
        check(CanvasPrimitiveElement.self, priority: 1)

        // Also check environment renderables (Symbols in schematic)
        for renderable in context.environment.renderables {
            if renderable.hitTest(point: point, tolerance: tolerance) {
                let id = NodeID(renderable.id)
                let area = renderable.renderBounds.width * renderable.renderBounds.height
                let candidate = GraphHitCandidate(id: id, priority: 5, area: area)
                if best == nil || candidate.priority > best!.priority
                    || (candidate.priority == best!.priority && candidate.area < best!.area)
                {
                    best = candidate
                }
            }
        }

        return best
    }

    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [NodeID] {
        var hits: Set<NodeID> = []

        func check<T: CanvasRenderable>(_ type: T.Type) {
            for (id, renderable) in graph.components(type) {
                if rect.intersects(renderable.renderBounds) {
                    hits.insert(id)
                }
            }
        }

        check(CanvasPin.self)
        check(CanvasText.self)
        check(CanvasPrimitiveElement.self)

        for renderable in context.environment.renderables {
            if rect.intersects(renderable.renderBounds) {
                hits.insert(NodeID(renderable.id))
            }
        }

        return Array(hits)
    }
}
