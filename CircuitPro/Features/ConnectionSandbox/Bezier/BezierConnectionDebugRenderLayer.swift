import AppKit

final class BezierConnectionDebugRenderLayer: RenderLayer {
    private let contentLayer = CALayer()

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(contentLayer)
    }

    func update(using context: RenderContext) {
        contentLayer.frame = context.hostViewBounds
        contentLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        guard let engine = context.connectionEngine else { return }

        let routingContext = ConnectionRoutingContext { point in
            context.snapProvider.snap(point: point, context: context)
        }
        let routes = engine.routes(
            points: context.connectionPoints,
            links: context.connectionLinks,
            context: routingContext
        )

        for (_, route) in routes {
            guard let bezier = route as? BezierRoute else { continue }
            let path = CGMutablePath()
            path.move(to: bezier.start)
            path.addCurve(to: bezier.end, control1: bezier.c1, control2: bezier.c2)

            let shape = CAShapeLayer()
            shape.path = path
            shape.strokeColor = NSColor.systemPurple.cgColor
            shape.lineWidth = 2
            shape.fillColor = nil
            contentLayer.addSublayer(shape)
        }

        for point in context.connectionPoints {
            let dot = CAShapeLayer()
            let rect = CGRect(x: point.position.x - 3, y: point.position.y - 3, width: 6, height: 6)
            dot.path = CGPath(ellipseIn: rect, transform: nil)
            dot.fillColor = NSColor.systemBlue.cgColor
            contentLayer.addSublayer(dot)
        }
    }
}
