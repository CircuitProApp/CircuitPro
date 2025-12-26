//
//  GraphTextHitTestProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics

struct GraphTextHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext) -> GraphHitCandidate? {
        var best: GraphHitCandidate?

        for (id, component) in graph.components(GraphTextComponent.self) {
            guard component.isVisible else { continue }
            let worldPath = component.worldPath()
            let bounds = worldPath.boundingBoxOfPath
            guard !bounds.isNull else { continue }

            if bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
                let candidate = GraphHitCandidate(id: id, priority: 2, area: bounds.width * bounds.height)
                if let current = best {
                    if candidate.priority > current.priority ||
                        (candidate.priority == current.priority && candidate.area < current.area) {
                        best = candidate
                    }
                } else {
                    best = candidate
                }
            }
        }

        return best
    }

    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [NodeID] {
        var hits = Set<NodeID>()

        for (id, component) in graph.components(GraphTextComponent.self) {
            guard component.isVisible else { continue }
            let worldPath = component.worldPath()
            let bounds = worldPath.boundingBoxOfPath
            guard !bounds.isNull else { continue }

            if rect.intersects(bounds) {
                hits.insert(id)
            }
        }

        return Array(hits)
    }
}
