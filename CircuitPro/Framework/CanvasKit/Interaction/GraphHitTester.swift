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

        return hits
    }
}
