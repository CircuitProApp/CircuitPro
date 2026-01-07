import AppKit

final class ConnectionDebugRenderLayer: RenderLayer {
    private let contentLayer = CALayer()

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(contentLayer)
    }

    func update(using context: RenderContext) {
        contentLayer.frame = context.hostViewBounds
        contentLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        guard let engine = context.connectionEngine else { return }

        let input = ConnectionInput.edges(
            anchors: context.connectionAnchors,
            edges: context.connectionEdges
        )
        let routingContext = ConnectionRoutingContext { point in
            context.snapProvider.snap(point: point, context: context)
        }
        let routes = engine.routes(from: input, context: routingContext)

        for (_, route) in routes {
            guard let manhattan = route as? ManhattanRoute else { continue }
            guard let first = manhattan.points.first else { continue }

            let path = CGMutablePath()
            path.move(to: first)
            for point in manhattan.points.dropFirst() {
                path.addLine(to: point)
            }

            let shape = CAShapeLayer()
            shape.path = path
            shape.strokeColor = NSColor.systemRed.cgColor
            shape.lineWidth = 2
            shape.fillColor = nil
            contentLayer.addSublayer(shape)
        }

        for anchor in context.connectionAnchors {
            let dot = CAShapeLayer()
            let rect = CGRect(x: anchor.position.x - 3, y: anchor.position.y - 3, width: 6, height: 6)
            dot.path = CGPath(ellipseIn: rect, transform: nil)
            dot.fillColor = NSColor.systemBlue.cgColor
            contentLayer.addSublayer(dot)
        }
    }
}
