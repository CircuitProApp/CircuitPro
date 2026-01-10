import AppKit

struct ConnectionDebugRL: CKRenderLayer {
    @CKContext var context

    var body: CKLayer {
        guard let engine = context.connectionEngine else {
            return .empty
        }

        let routingContext = ConnectionRoutingContext { point in
            context.snapProvider.snap(point: point, context: context)
        }
        let routes = engine.routes(
            points: context.connectionPoints,
            links: context.connectionLinks,
            context: routingContext
        )

        let path = CGMutablePath()
        for (id, route) in routes {
            guard let manhattan = route as? ManhattanRoute else { continue }
            let points = manhattan.points
            guard points.count >= 2 else { continue }

            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

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

        return CKLayer {
            CKPath(path: path)
                .stroke(color, width: 3.0)
            pointDots()
        }
    }

    private var color: CGColor {
        NSColor.systemBlue.cgColor
    }

    private func pointDots() -> CKLayer {
        let path = CGMutablePath()
        for point in context.connectionPoints {
            let rect = CGRect(x: point.position.x - 3, y: point.position.y - 3, width: 6, height: 6)
            path.addEllipse(in: rect)
        }
        return CKPath(path: path).fill(NSColor.systemBlue.cgColor).layer
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

        _ = CKLayer {
            CKPath(path: finalPath)
                .fill(NSColor.systemYellow.cgColor)
        }
    }
}
