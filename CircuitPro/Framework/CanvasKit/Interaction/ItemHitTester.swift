//
//  ItemHitTester.swift
//  CircuitPro
//
//  Created by Codex on 12/31/25.
//

import CoreGraphics

struct ItemHitTester {
    func hitTest(point: CGPoint, context: RenderContext) -> GraphElementID? {
        let tolerance = 5.0 / context.magnification
        var best: GraphHitCandidate?

        for item in context.items {
            guard let hitTestable = item as? (any HitTestable & Bounded) else { continue }
            if hitTestable.hitTest(point: point, tolerance: tolerance) {
                let area = hitTestable.boundingBox.width * hitTestable.boundingBox.height
                let priority = hitTestable.hitTestPriority
                considerHit(
                    id: .node(NodeID(item.id)),
                    priority: priority,
                    area: area,
                    best: &best
                )
            }
        }

        return best?.id
    }

    func hitTestAll(in rect: CGRect, context: RenderContext) -> [GraphElementID] {
        var hits = Set<GraphElementID>()

        for item in context.items {
            guard let bounded = item as? Bounded else { continue }
            if rect.intersects(bounded.boundingBox) {
                hits.insert(.node(NodeID(item.id)))
            }
        }

        return Array(hits)
    }

    private func considerHit(
        id: GraphElementID,
        priority: Int,
        area: CGFloat,
        best: inout GraphHitCandidate?
    ) {
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
