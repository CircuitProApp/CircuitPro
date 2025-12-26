//
//  TraceGraphHitTestProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics

struct TraceGraphHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext) -> GraphHitCandidate? {
        var best: GraphHitCandidate?

        for (id, edge) in graph.components(TraceEdgeComponent.self) {
            guard let start = graph.component(TraceVertexComponent.self, for: edge.start),
                  let end = graph.component(TraceVertexComponent.self, for: edge.end) else {
                continue
            }
            if isPoint(point, onSegmentBetween: start.point, p2: end.point, tolerance: tolerance, strokeWidth: edge.width) {
                let length = hypot(end.point.x - start.point.x, end.point.y - start.point.y)
                let area = length * max(edge.width, 1.0)
                let candidate = GraphHitCandidate(id: id, priority: 1, area: area)
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
        var hits: [NodeID] = []

        for (id, edge) in graph.components(TraceEdgeComponent.self) {
            guard let start = graph.component(TraceVertexComponent.self, for: edge.start),
                  let end = graph.component(TraceVertexComponent.self, for: edge.end) else {
                continue
            }
            let inset = max(2.0, edge.width / 2)
            let bounds = CGRect(
                x: min(start.point.x, end.point.x),
                y: min(start.point.y, end.point.y),
                width: abs(start.point.x - end.point.x),
                height: abs(start.point.y - end.point.y)
            ).insetBy(dx: -inset, dy: -inset)
            if rect.intersects(bounds) {
                hits.append(id)
            }
        }

        return hits
    }

    private func isPoint(_ p: CGPoint, onSegmentBetween p1: CGPoint, p2: CGPoint, tolerance: CGFloat, strokeWidth: CGFloat) -> Bool {
        let padding = tolerance + (strokeWidth / 2)
        let minX = min(p1.x, p2.x) - padding, maxX = max(p1.x, p2.x) + padding
        let minY = min(p1.y, p2.y) - padding, maxY = max(p1.y, p2.y) + padding

        guard p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY else { return false }

        let dx = p2.x - p1.x
        let dy = p2.y - p1.y

        let epsilon: CGFloat = 1e-6
        if abs(dx) < epsilon { return abs(p.x - p1.x) < padding }
        if abs(dy) < epsilon { return abs(p.y - p1.y) < padding }

        let distance = abs(dy * p.x - dx * p.y + p2.y * p1.x - p2.x * p1.y) / hypot(dx, dy)

        return distance < padding
    }
}
