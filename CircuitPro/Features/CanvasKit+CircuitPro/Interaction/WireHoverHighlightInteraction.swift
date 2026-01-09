import AppKit

final class WireHoverHighlightInteraction: CanvasInteraction {
    func mouseMoved(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard controller.selectedTool is CursorTool else {
            controller.setInteractionLinkHighlight(linkIDs: [])
            return
        }
        guard let engine = context.connectionEngine else {
            controller.setInteractionLinkHighlight(linkIDs: [])
            return
        }

        let tolerance = 6.0 / max(context.magnification, 0.001)
        let routingContext = ConnectionRoutingContext { snapPoint in
            context.snapProvider.snap(point: snapPoint, context: context)
        }
        let routes = engine.routes(
            points: context.connectionPoints,
            links: context.connectionLinks,
            context: routingContext
        )

        var bestID: UUID?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for (id, route) in routes {
            guard let manhattan = route as? ManhattanRoute else { continue }
            let points = manhattan.points
            guard points.count >= 2 else { continue }

            for idx in 0..<(points.count - 1) {
                let a = points[idx]
                let b = points[idx + 1]
                let distance = distance(from: point, toSegmentBetween: a, and: b)
                if distance <= tolerance && distance < bestDistance {
                    bestDistance = distance
                    bestID = id
                }
            }
        }

        if let bestID {
            controller.setInteractionLinkHighlight(linkIDs: [bestID])
        } else {
            controller.setInteractionLinkHighlight(linkIDs: [])
        }
    }

    private func distance(from target: CGPoint, toSegmentBetween a: CGPoint, and b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 <= .ulpOfOne {
            return hypot(target.x - a.x, target.y - a.y)
        }
        let t = ((target.x - a.x) * dx + (target.y - a.y) * dy) / len2
        let clamped = min(max(t, 0), 1)
        let proj = CGPoint(x: a.x + clamped * dx, y: a.y + clamped * dy)
        return hypot(target.x - proj.x, target.y - proj.y)
    }
}
