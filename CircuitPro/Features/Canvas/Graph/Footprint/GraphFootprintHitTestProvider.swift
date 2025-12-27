import CoreGraphics

struct GraphFootprintHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext) -> GraphHitCandidate? {
        var best: GraphHitCandidate?

        for (id, component) in graph.components(GraphFootprintComponent.self) {
            let bounds = component.worldInteractionBounds()
            if let bounds,
               !bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
                continue
            }

            let ownerInverse = component.ownerTransform.inverted()
            let localPoint = point.applying(ownerInverse)

            for primitive in component.primitives {
                let primTransform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                    .rotated(by: primitive.rotation)
                let primLocal = localPoint.applying(primTransform.inverted())
                if primitive.hitTest(primLocal, tolerance: tolerance) != nil {
                    let area = (bounds?.width ?? 0) * (bounds?.height ?? 0)
                    let candidate = GraphHitCandidate(id: id, priority: 1, area: area)
                    if let current = best {
                        if candidate.priority > current.priority ||
                            (candidate.priority == current.priority && candidate.area < current.area) {
                            best = candidate
                        }
                    } else {
                        best = candidate
                    }
                    break
                }
            }
        }

        return best
    }

    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [NodeID] {
        var hits = Set<NodeID>()

        for (id, component) in graph.components(GraphFootprintComponent.self) {
            guard let bounds = component.worldInteractionBounds() else { continue }
            if rect.intersects(bounds) {
                hits.insert(id)
            }
        }

        return Array(hits)
    }
}
