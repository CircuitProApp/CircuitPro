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

        for (id, item) in graph.componentsConforming((any HitTestable & Bounded).self) {
            if item.hitTest(point: point, tolerance: tolerance) {
                let area = item.boundingBox.width * item.boundingBox.height
                let priority = (item as? HitTestPriorityProviding)?.hitTestPriority ?? 0
                considerHit(id: id, priority: priority, area: area, best: &best)
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

        for (id, item) in graph.componentsConforming((any Bounded).self) {
            if rect.intersects(item.boundingBox) {
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
