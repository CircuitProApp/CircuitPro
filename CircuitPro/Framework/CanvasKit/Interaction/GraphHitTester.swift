//
//  GraphHitTester.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation

struct GraphHitTester {
    enum Scope {
        case all
        case graphOnly
    }

    func hitTest(point: CGPoint, context: RenderContext, scope: Scope = .all) -> NodeID? {
        guard let graph = context.graph else { return nil }
        let tolerance = 5.0 / context.magnification
        var best: (id: NodeID, priority: Int, area: CGFloat)?

        if scope == .all {
            for (id, component) in graph.components(GraphNodeComponent.self) {
                guard let node = findNode(id: id, in: context.sceneRoot),
                      node.isVisible else { continue }
                let localPoint = point.applying(node.worldTransform.inverted())
                guard node.hitTest(localPoint, tolerance: tolerance) != nil else { continue }
                let bounds = node.interactionBounds.applying(node.worldTransform)
                let area = bounds.width * bounds.height
                considerHit(id: id, priority: component.kind.priority, area: area, best: &best)
            }
        }

        for (id, primitive) in graph.components(AnyCanvasPrimitive.self) {
            let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            let localPoint = point.applying(transform.inverted())
            if primitive.hitTest(localPoint, tolerance: tolerance) != nil {
                considerHit(id: id, priority: 1, area: primitive.boundingBox.width * primitive.boundingBox.height, best: &best)
            }
        }

        for (id, edge) in graph.components(WireEdgeComponent.self) {
            guard let start = graph.component(WireVertexComponent.self, for: edge.start),
                  let end = graph.component(WireVertexComponent.self, for: edge.end) else {
                continue
            }
            if isPoint(point, onSegmentBetween: start.point, p2: end.point, tolerance: tolerance, strokeWidth: 0) {
                considerHit(id: id, priority: 0, area: 0.0, best: &best)
            }
        }

        for (id, edge) in graph.components(TraceEdgeComponent.self) {
            guard let start = graph.component(TraceVertexComponent.self, for: edge.start),
                  let end = graph.component(TraceVertexComponent.self, for: edge.end) else {
                continue
            }
            if isPoint(point, onSegmentBetween: start.point, p2: end.point, tolerance: tolerance, strokeWidth: edge.width) {
                let length = hypot(end.point.x - start.point.x, end.point.y - start.point.y)
                considerHit(id: id, priority: 1, area: length * max(edge.width, 1.0), best: &best)
            }
        }

        return best?.id
    }

    func hitTestAll(in rect: CGRect, context: RenderContext, scope: Scope = .all) -> [NodeID] {
        guard let graph = context.graph else { return [] }

        var hits = Set<NodeID>()

        if scope == .all {
            for (id, _) in graph.components(GraphNodeComponent.self) {
                guard let node = findNode(id: id, in: context.sceneRoot),
                      node.isVisible else { continue }
                let bounds = node.interactionBounds.applying(node.worldTransform)
                if rect.intersects(bounds) {
                    hits.insert(id)
                }
            }
        }

        for (id, primitive) in graph.components(AnyCanvasPrimitive.self) {
            let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            let localRect = rect.applying(transform.inverted())
            if primitive.boundingBox.intersects(localRect) {
                hits.insert(id)
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
                hits.insert(id)
            }
        }

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
                hits.insert(id)
            }
        }

        return Array(hits)
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

    private func considerHit(id: NodeID, priority: Int, area: CGFloat, best: inout (id: NodeID, priority: Int, area: CGFloat)?) {
        guard let current = best else {
            best = (id: id, priority: priority, area: area)
            return
        }
        if priority > current.priority || (priority == current.priority && area < current.area) {
            best = (id: id, priority: priority, area: area)
        }
    }

    private func findNode(id: NodeID, in root: BaseNode) -> BaseNode? {
        if root.id == id.rawValue {
            return root
        }
        for child in root.children {
            if let found = findNode(id: id, in: child) {
                return found
            }
        }
        return nil
    }
}
