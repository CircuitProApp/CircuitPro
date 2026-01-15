import AppKit

struct ConnectionDebugRL: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let engine: any ConnectionEngine

    @CKViewBuilder var body: some CKView {
        if true {
            let routingContext = ConnectionRoutingContext { point in
                context.snapProvider.snap(point: point, context: context, environment: environment)
            }
            let routes = engine.routes(
                points: context.connectionPoints,
                links: context.connectionLinks,
                context: routingContext
            )

            let (routePath, labelPath) = routeAndLabelPaths(
                routes: routes,
                links: context.connectionLinks,
                pointsByID: context.connectionPointPositionsByID
            )

            CKGroup {
                CKPath(path: routePath)
                    .stroke(color, width: 3.0)
                if !labelPath.isEmpty {
                    CKPath(path: labelPath)
                        .fill(NSColor.systemYellow.cgColor)
                }
                pointDots()
            }
        }
    }

    private var color: CGColor {
        NSColor.systemBlue.cgColor
    }

    private func pointDots() -> some CKView {
        let path = CGMutablePath()
        for point in context.connectionPoints {
            let rect = CGRect(x: point.position.x - 3, y: point.position.y - 3, width: 6, height: 6)
            path.addEllipse(in: rect)
        }
        return CKPath(path: path).fill(NSColor.systemBlue.cgColor)
    }

    private func routeAndLabelPaths(
        routes: [UUID: any ConnectionRoute],
        links: [any ConnectionLink],
        pointsByID: [UUID: CGPoint]
    ) -> (CGPath, CGPath) {
        let routePath = CGMutablePath()
        let labelsPath = CGMutablePath()

        for (id, route) in routes {
            guard let manhattan = route as? ManhattanRoute else { continue }
            let points = manhattan.points
            guard points.count >= 2 else { continue }

            routePath.move(to: points[0])
            for point in points.dropFirst() {
                routePath.addLine(to: point)
            }

            if let link = links.first(where: { $0.id == id }),
               let start = pointsByID[link.startID],
               let end = pointsByID[link.endID],
               let label = makeLabelPath(
                id: id,
                startID: link.startID,
                endID: link.endID,
                start: start,
                end: end
               ) {
                labelsPath.addPath(label)
            }
        }

        return (routePath, labelsPath)
    }

    private func makeLabelPath(
        id: UUID,
        startID: UUID,
        endID: UUID,
        start: CGPoint,
        end: CGPoint
    ) -> CGPath? {
        let mid = CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)
        let text = "\(id.uuidString.prefix(4)) \(startID.uuidString.prefix(4))→\(endID.uuidString.prefix(4))"
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let textPath = CKText.path(for: text, font: font)
        let bounds = textPath.boundingBoxOfPath
        guard !bounds.isEmpty else { return nil }
        let position = CGPoint(x: mid.x - bounds.width / 2, y: mid.y - bounds.height / 2)
        let transform = CGAffineTransform(
            translationX: position.x - bounds.minX,
            y: position.y - bounds.minY
        )
        let finalPath = CGMutablePath()
        finalPath.addPath(textPath, transform: transform)
        return finalPath
    }
}
