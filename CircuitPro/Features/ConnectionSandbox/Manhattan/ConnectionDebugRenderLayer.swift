import AppKit

final class ConnectionDebugRenderLayer: RenderLayer {
    private let contentLayer = CALayer()

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(contentLayer)
    }

    func update(using context: RenderContext) {
        contentLayer.frame = context.canvasBounds
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

        for (id, route) in routes {
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
            shape.strokeColor = color(for: id).cgColor
            shape.lineWidth = 3.0
            shape.lineCap = .round
            shape.fillColor = nil
            contentLayer.addSublayer(shape)

            if let link = context.connectionLinks.first(where: { $0.id == id }),
               let start = context.connectionPointPositionsByID[link.startID],
               let end = context.connectionPointPositionsByID[link.endID] {
                addLinkLabel(
                    id: id,
                    startID: link.startID,
                    endID: link.endID,
                    start: start,
                    end: end
                )
            }
        }

        for point in context.connectionPoints {
            let dot = CAShapeLayer()
            let rect = CGRect(x: point.position.x - 3, y: point.position.y - 3, width: 6, height: 6)
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

    private func addLinkLabel(
        id: UUID,
        startID: UUID,
        endID: UUID,
        start: CGPoint,
        end: CGPoint
    ) {
        let mid = CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)
        let text = "\(id.uuidString.prefix(4)) \(startID.uuidString.prefix(4))→\(endID.uuidString.prefix(4))"
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let textPath = CKText.path(for: text, font: font)
        let bounds = textPath.boundingBoxOfPath
        let position = CGPoint(x: mid.x - bounds.width / 2, y: mid.y - bounds.height / 2)
        let transform = CGAffineTransform(
            translationX: position.x - bounds.minX,
            y: position.y - bounds.minY
        )
        let finalPath = CGMutablePath()
        finalPath.addPath(textPath, transform: transform)

        let textLayer = CAShapeLayer()
        textLayer.path = finalPath
        textLayer.fillColor = NSColor.systemYellow.cgColor
        textLayer.strokeColor = nil
        contentLayer.addSublayer(textLayer)
    }
}
