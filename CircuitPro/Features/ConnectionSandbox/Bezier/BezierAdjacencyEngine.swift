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
        from input: ConnectionInput,
        context: ConnectionRoutingContext
    ) -> [UUID: any ConnectionRoute] {
        guard case let .adjacency(anchors, points) = input else { return [:] }

        let anchorsByID = Dictionary(uniqueKeysWithValues: anchors.map { ($0.id, $0.position) })
        var output: [UUID: any ConnectionRoute] = [:]
        var seen = Set<String>()

        for point in points {
            for otherID in point.connectedIDs {
                let key = point.id.uuidString < otherID.uuidString
                    ? "\(point.id.uuidString)|\(otherID.uuidString)"
                    : "\(otherID.uuidString)|\(point.id.uuidString)"
                if seen.contains(key) { continue }
                seen.insert(key)

                guard let a = anchorsByID[point.id],
                      let b = anchorsByID[otherID]
                else { continue }

                let start = context.snapPoint(a)
                let end = context.snapPoint(b)
                let dx = abs(end.x - start.x)
                let control = max(dx * 0.5, minControl)
                let c1 = CGPoint(x: start.x + control, y: start.y)
                let c2 = CGPoint(x: end.x - control, y: end.y)

                output[UUID()] = BezierRoute(start: start, c1: c1, c2: c2, end: end)
            }
        }

        return output
    }
}
