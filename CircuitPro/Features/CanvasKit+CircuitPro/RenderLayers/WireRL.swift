import AppKit

struct WireRL: CKView {
    @CKContext var context
    @CKEnvironment var environment

    var wireColor: CKColor {
        CKColor(environment.schematicTheme.wireColor)
    }

    var body: some CKView {
        if let engine = environment.connectionEngine {
            let routingContext = ConnectionRoutingContext { point in
                context.snapProvider.snap(point: point, context: context, environment: environment)
            }
            let routes = engine.routes(
                points: context.connectionPoints,
                links: context.connectionLinks,
                context: routingContext
            )
            let activeLinkIDs = context.selectedItemIDs
                .union(context.highlightedItemIDs)
            CKGroup {
                for linkID in routes.keys {
                    if let path = routePath(for: linkID, routes: routes) {
                        let isHighlighted = activeLinkIDs.contains(linkID)
                        CKPath(path: path)
                            .halo(isHighlighted ? wireColor.haloOpacity() : .clear, width: 5)
                            .stroke(wireColor, width: 1)
                            .hoverable(linkID)
                            .selectable(linkID)
                    }
                }

                let dotPath = junctionDotsPath(
                    pointsByID: context.connectionPointPositionsByID,
                    links: context.connectionLinks,
                    dotRadius: 3.0
                )
                if !dotPath.isEmpty {
                    CKPath(path: dotPath)
                        .fill(wireColor)
                }
            }
        } else {
            CKEmpty()
        }
    }

    private func routePath(
        for linkID: UUID,
        routes: [UUID: any ConnectionRoute]
    ) -> CGPath? {
        guard let route = routes[linkID] as? ManhattanRoute else { return nil }
        let points = route.points
        guard points.count >= 2 else { return nil }
        let path = CGMutablePath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path.isEmpty ? nil : path
    }

    private func junctionDotsPath(
        pointsByID: [UUID: CGPoint],
        links: [any ConnectionLink],
        dotRadius: CGFloat
    ) -> CGPath {
        var degreeByID: [UUID: Int] = [:]
        for link in links {
            degreeByID[link.startID, default: 0] += 1
            degreeByID[link.endID, default: 0] += 1
        }

        let path = CGMutablePath()
        for (id, degree) in degreeByID where degree >= 3 {
            guard let position = pointsByID[id] else { continue }
            let rect = CGRect(
                x: position.x - dotRadius,
                y: position.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            path.addEllipse(in: rect)
        }
        return path
    }
}
