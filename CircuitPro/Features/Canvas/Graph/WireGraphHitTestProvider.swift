//
//  WireGraphHitTestProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics

struct WireGraphHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext) -> GraphHitCandidate? {
        for (edgeID, edge) in graph.edgeComponents(WireEdgeComponent.self) {
            if isPoint(point, onSegmentBetween: edge.startPoint, p2: edge.endPoint, tolerance: tolerance, strokeWidth: edge.lineWidth) {
                return GraphHitCandidate(id: .edge(edgeID), priority: 0, area: 0.0)
            }
        }
        return nil
    }

    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [GraphElementID] {
        var hits: [GraphElementID] = []

        for (edgeID, edge) in graph.edgeComponents(WireEdgeComponent.self) {
            let inset = max(2.0, edge.lineWidth / 2)
            let bounds = CGRect(
                x: min(edge.startPoint.x, edge.endPoint.x),
                y: min(edge.startPoint.y, edge.endPoint.y),
                width: abs(edge.startPoint.x - edge.endPoint.x),
                height: abs(edge.startPoint.y - edge.endPoint.y)
            ).insetBy(dx: -inset, dy: -inset)
            if rect.intersects(bounds) {
                hits.append(.edge(edgeID))
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
