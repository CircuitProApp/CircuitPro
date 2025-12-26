//
//  GraphHitTester.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation

struct GraphHitTester {
    func hitTest(point: CGPoint, context: RenderContext) -> NodeID? {
        guard let graph = context.graph else { return nil }
        let tolerance = 5.0 / context.magnification

        for (id, primitive) in graph.components(AnyCanvasPrimitive.self) {
            let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            let localPoint = point.applying(transform.inverted())
            if primitive.hitTest(localPoint, tolerance: tolerance) != nil {
                return id
            }
        }

        for (id, edge) in graph.components(WireEdgeComponent.self) {
            guard let start = graph.component(WireVertexComponent.self, for: edge.start),
                  let end = graph.component(WireVertexComponent.self, for: edge.end) else {
                continue
            }
            if isPoint(point, onSegmentBetween: start.point, p2: end.point, tolerance: tolerance) {
                return id
            }
        }

        return nil
    }

    func hitTestAll(in rect: CGRect, context: RenderContext) -> [NodeID] {
        guard let graph = context.graph else { return [] }

        var hits: [NodeID] = []

        for (id, primitive) in graph.components(AnyCanvasPrimitive.self) {
            let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            let localRect = rect.applying(transform.inverted())
            if primitive.boundingBox.intersects(localRect) {
                hits.append(id)
            }
        }

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

    private func isPoint(_ p: CGPoint, onSegmentBetween p1: CGPoint, p2: CGPoint, tolerance: CGFloat) -> Bool {
        let minX = min(p1.x, p2.x) - tolerance, maxX = max(p1.x, p2.x) + tolerance
        let minY = min(p1.y, p2.y) - tolerance, maxY = max(p1.y, p2.y) + tolerance

        guard p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY else { return false }

        let dx = p2.x - p1.x
        let dy = p2.y - p1.y

        let epsilon: CGFloat = 1e-6
        if abs(dx) < epsilon { return abs(p.x - p1.x) < tolerance }
        if abs(dy) < epsilon { return abs(p.y - p1.y) < tolerance }

        let distance = abs(dy * p.x - dx * p.y + p2.y * p1.x - p2.x * p1.y) / hypot(dx, dy)

        return distance < tolerance
    }
}
