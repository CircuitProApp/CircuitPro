//
//  GraphPadHitTestProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics

struct GraphPadHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext) -> GraphHitCandidate? {
        var best: GraphHitCandidate?

        for (id, component) in graph.components(CanvasPad.self) {
            let localPoint = point.applying(component.worldTransform.inverted())
            let bodyPath = component.pad.calculateCompositePath()
            let hitArea = bodyPath.copy(
                strokingWithWidth: tolerance,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 1
            )
            if hitArea.contains(localPoint) {
                let bounds = bodyPath.boundingBoxOfPath
                let area = bounds.width * bounds.height
                let candidate = GraphHitCandidate(id: .node(id), priority: 2, area: area)
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

    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [GraphElementID] {
        var hits = Set<GraphElementID>()
        for (id, component) in graph.components(CanvasPad.self) {
            let bodyPath = component.pad.calculateCompositePath()
            let bounds = bodyPath.boundingBoxOfPath
            if bounds.isNull { continue }

            var transform = component.worldTransform
            let worldBounds = bounds.applying(transform)
            if rect.intersects(worldBounds) {
                hits.insert(.node(id))
            }
        }

        return Array(hits)
    }
}
