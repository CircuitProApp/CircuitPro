import AppKit

struct WireRL: CKView {
    @CKContext var context
    @CKEnvironment var environment

     @CKViewBuilder var body: some CKView {
        if let engine = environment.connectionEngine {
            let routingContext = ConnectionRoutingContext { point in
                context.snapProvider.snap(point: point, context: context, environment: environment)
            }
            let routes = engine.routes(
                points: context.connectionPoints,
                links: context.connectionLinks,
                context: routingContext
            )

            let strokeColor = environment.schematicTheme.wireColor
            let haloWidth: CGFloat = 6.0
            let lineWidth: CGFloat = 1.0

            let linkIDs = Set(context.connectionLinks.map { $0.id })
            let selectedLinkIDs = linkIDs.intersection(context.highlightedItemIDs)

            CKGroup {
                if let selectionPath = combinedPath(for: selectedLinkIDs, routes: routes),
                   let selectionColor = NSColor(cgColor: strokeColor)?
                    .withAlphaComponent(0.45)
                    .cgColor {
                    CKPath(path: selectionPath)
                        .halo(selectionColor, width: haloWidth)
                }

                if let hoverPath = combinedPath(for: context.highlightedLinkIDs, routes: routes),
                   let hoverColor = NSColor(cgColor: strokeColor)?
                    .withAlphaComponent(0.35)
                    .cgColor {
                    CKPath(path: hoverPath)
                        .halo(hoverColor, width: haloWidth)
                }

                if let basePath = combinedPath(for: linkIDs, routes: routes) {
                    CKPath(path: basePath)
                        .stroke(strokeColor, width: lineWidth)
                }

                let dotPath = junctionDotsPath(
                    pointsByID: context.connectionPointPositionsByID,
                    links: context.connectionLinks,
                    dotRadius: 3.0
                )
                if !dotPath.isEmpty {
                    CKPath(path: dotPath)
                        .fill(strokeColor)
                }
            }
        } else {
            CKEmpty()
        }
    }

    private func combinedPath(
        for linkIDs: Set<UUID>,
        routes: [UUID: any ConnectionRoute]
    ) -> CGPath? {
        guard !linkIDs.isEmpty else { return nil }
        let path = CGMutablePath()
        for linkID in linkIDs {
            guard let route = routes[linkID] as? ManhattanRoute else { continue }
            let points = route.points
            guard points.count >= 2 else { continue }
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
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
