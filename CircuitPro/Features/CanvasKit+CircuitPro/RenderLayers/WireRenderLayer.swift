import AppKit

final class WireRenderLayer: RenderLayer {
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

        let strokeColor = context.environment.canvasTheme.textColor
        for route in routes.values {
            guard let manhattan = route as? ManhattanRoute else { continue }
            let points = manhattan.points
            guard points.count >= 2 else { continue }

            let path = CGMutablePath()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            let shape = CAShapeLayer()
            shape.path = path
            shape.strokeColor = strokeColor
            shape.lineWidth = 2.0
            shape.lineCap = .round
            shape.lineJoin = .round
            shape.fillColor = nil
            contentLayer.addSublayer(shape)
        }
    }
}
