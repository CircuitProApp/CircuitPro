//
//  GraphHitTester.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import CoreGraphics

struct GraphHitTester {
    func hitTest(point: CGPoint, context: RenderContext) -> NodeID? {
        let graph = context.graph
        let tolerance = 5.0 / context.magnification
        var best: GraphHitCandidate?

        for (id, primitive) in graph.components(AnyCanvasPrimitive.self) {
            let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            let localPoint = point.applying(transform.inverted())
            if primitive.hitTest(localPoint, tolerance: tolerance) != nil {
                considerHit(id: id, priority: 1, area: primitive.boundingBox.width * primitive.boundingBox.height, best: &best)
            }
        }

        for provider in context.environment.graphHitTestProviders {
            if let candidate = provider.hitTest(point: point, tolerance: tolerance, graph: graph, context: context) {
                considerHit(candidate: candidate, best: &best)
            }
        }

        return best?.id
    }

    func hitTestAll(in rect: CGRect, context: RenderContext) -> [NodeID] {
        let graph = context.graph
        var hits = Set<NodeID>()

        for (id, primitive) in graph.components(AnyCanvasPrimitive.self) {
            let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            let localRect = rect.applying(transform.inverted())
            if primitive.boundingBox.intersects(localRect) {
                hits.insert(id)
            }
        }

        for provider in context.environment.graphHitTestProviders {
            hits.formUnion(provider.hitTestAll(in: rect, graph: graph, context: context))
        }

        return Array(hits)
    }

    private func considerHit(id: NodeID, priority: Int, area: CGFloat, best: inout GraphHitCandidate?) {
        considerHit(candidate: GraphHitCandidate(id: id, priority: priority, area: area), best: &best)
    }

    private func considerHit(candidate: GraphHitCandidate, best: inout GraphHitCandidate?) {
        guard let current = best else {
            best = candidate
            return
        }
        if candidate.priority > current.priority ||
            (candidate.priority == current.priority && candidate.area < current.area) {
            best = candidate
        }
    }

}
