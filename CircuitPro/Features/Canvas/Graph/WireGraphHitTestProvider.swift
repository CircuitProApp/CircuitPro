//
//  WireGraphHitTestProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics

struct WireGraphHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext) -> GraphHitCandidate? {
        for (id, edge) in graph.components(WireEdgeComponent.self) {
            guard let start = graph.component(WireVertexComponent.self, for: edge.start),
                  let end = graph.component(WireVertexComponent.self, for: edge.end) else {
                continue
            }
            if isPoint(point, onSegmentBetween: start.point, p2: end.point, tolerance: tolerance, strokeWidth: 0) {
                return GraphHitCandidate(id: id, priority: 0, area: 0.0)
            }
        }
        return nil
    }

    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [NodeID] {
        var hits: [NodeID] = []

        for (id, edge) in graph.components(WireEdgeComponent.self) {
            guard let start = graph.component(WireVertexComponent.self, for: edge.start),
                  let end = graph.component(WireVertexComponent.self, for: edge.end) else {
                continue
            }
            let bounds = CGRect(
                x: min(start.point.x, end.point.x),
                y: min(start.point.y, end.point.y),
                width: abs(start.point.x - end.point.x),
                height: abs(start.point.y - end.point.y)
            ).insetBy(dx: -2.0, dy: -2.0)
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
