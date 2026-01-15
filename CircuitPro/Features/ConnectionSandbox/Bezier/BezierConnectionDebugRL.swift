import AppKit

struct BezierConnectionDebugRL: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let engine: any ConnectionEngine

    @CKViewBuilder var body: some CKView {
        let points = connectionPoints(from: context.items)
        let routingContext = ConnectionRoutingContext { point in
            context.snapProvider.snap(point: point, context: context, environment: environment)
        }
        let routes = engine.routes(
            points: points,
            links: context.connectionLinks,
            context: routingContext
        )

        let path = routePath(routes: routes)

        CKGroup {
            CKPath(path: path)
                .stroke(NSColor.systemPurple.cgColor, width: 2)
            pointDots(points: points)
        }
    }

    private struct SocketPoint: ConnectionPoint {
        let id: UUID
        let position: CGPoint
    }

    private func connectionPoints(from items: [any CanvasItem]) -> [SocketPoint] {
        var points: [SocketPoint] = []
        for item in items {
            guard let node = item as? SandboxNode else { continue }
            for socket in node.sockets {
                points.append(SocketPoint(id: socket.id, position: node.socketPosition(for: socket)))
            }
        }
        return points
    }

    private func routePath(routes: [UUID: any ConnectionRoute]) -> CGPath {
        let path = CGMutablePath()
        for route in routes.values {
            guard let bezier = route as? BezierRoute else { continue }
            path.move(to: bezier.start)
            path.addCurve(to: bezier.end, control1: bezier.c1, control2: bezier.c2)
        }
        return path
    }

    private func pointDots(points: [SocketPoint]) -> some CKView {
        let path = CGMutablePath()
        for point in points {
            let rect = CGRect(x: point.position.x - 3, y: point.position.y - 3, width: 6, height: 6)
            path.addEllipse(in: rect)
        }
        return CKPath(path: path).fill(NSColor.systemBlue.cgColor)
    }
}
