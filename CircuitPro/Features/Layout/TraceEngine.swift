import CoreGraphics
import Foundation

struct TraceRoute: ConnectionRoute {
    let points: [CGPoint]
}

struct TraceEngine: ConnectionEngine {
    var preferHorizontalFirst: Bool = true

    func routes(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionRoutingContext
    ) -> [UUID: any ConnectionRoute] {
        let pointsByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        var output: [UUID: any ConnectionRoute] = [:]
        output.reserveCapacity(links.count)

        for link in links {
            guard let a = pointsByID[link.startID],
                  let b = pointsByID[link.endID]
            else { continue }

            let start = context.snapPoint(a)
            let end = context.snapPoint(b)
            let pathPoints = route(from: start, to: end)
            output[link.id] = TraceRoute(points: pathPoints)
        }

        return output
    }

    func route(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let dx = abs(delta.x)
        let dy = abs(delta.y)

        if dx < 1e-6 || dy < 1e-6 || abs(dx - dy) < 1e-6 {
            return [start, end]
        }

        let diagonalLength = min(dx, dy)
        let corner = CGPoint(
            x: start.x + diagonalLength * delta.x.sign(),
            y: start.y + diagonalLength * delta.y.sign()
        )

        if hypot(corner.x - end.x, corner.y - end.y) < 1e-6 {
            return [start, end]
        }

        if preferHorizontalFirst {
            return [start, CGPoint(x: end.x, y: start.y), end]
        }
        return [start, CGPoint(x: start.x, y: end.y), end]
    }

}

private extension CGFloat {
    func sign() -> CGFloat {
        (self > 0) ? 1 : ((self < 0) ? -1 : 0)
    }
}
