import CoreGraphics
import Foundation

struct BezierRoute: ConnectionRoute {
    let start: CGPoint
    let c1: CGPoint
    let c2: CGPoint
    let end: CGPoint
}

struct BezierAdjacencyEngine: ConnectionEngine {
    var minControl: CGFloat = 40

    func routes(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionRoutingContext
    ) -> [UUID: any ConnectionRoute] {
        let pointsByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        var output: [UUID: any ConnectionRoute] = [:]

        for link in links {
            guard let a = pointsByID[link.startID],
                  let b = pointsByID[link.endID]
            else { continue }

            let start = context.snapPoint(a)
            let end = context.snapPoint(b)
            let dx = abs(end.x - start.x)
            let control = max(dx * 0.5, minControl)
            let c1 = CGPoint(x: start.x + control, y: start.y)
            let c2 = CGPoint(x: end.x - control, y: end.y)

            output[link.id] = BezierRoute(start: start, c1: c1, c2: c2, end: end)
        }

        return output
    }
}
