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

        let mergedSegments = mergeSegments(from: routes.values, magnification: context.magnification)
        for segment in mergedSegments {
            guard let manhattan = route as? ManhattanRoute else { continue }
            guard let first = manhattan.points.first else { continue }
            // placeholder
        }

        for anchor in context.connectionAnchors {
            let dot = CAShapeLayer()
            let rect = CGRect(x: anchor.position.x - 3, y: anchor.position.y - 3, width: 6, height: 6)
            dot.path = CGPath(ellipseIn: rect, transform: nil)
            dot.fillColor = NSColor.systemBlue.cgColor
            contentLayer.addSublayer(dot)
        }
    }

    private func color(for id: UUID) -> NSColor {
        let hex = id.uuidString.replacingOccurrences(of: "-", with: "")
        let prefix = hex.prefix(6)
        let value = Int(prefix, radix: 16) ?? 0
        let hue = CGFloat(value % 360) / 360.0
        return NSColor(calibratedHue: hue, saturation: 0.7, brightness: 0.9, alpha: 0.6)
    }
}
