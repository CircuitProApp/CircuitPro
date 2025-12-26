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
        var best: GraphHitCandidate?

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

        for provider in context.environment.graphHitTestProviders {
            if let candidate = provider.hitTest(point: point, tolerance: tolerance, graph: graph, context: context) {
                considerHit(candidate: candidate, best: &best)
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
