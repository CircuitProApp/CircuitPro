import CoreGraphics
import Foundation

struct ManhattanRoute: ConnectionRoute {
    let points: [CGPoint]
}

struct ManhattanWireEngine: ConnectionEngine {
    var preferHorizontalFirst: Bool = true

    func routes(
        from input: ConnectionInput,
        context: ConnectionRoutingContext
    ) -> [UUID: any ConnectionRoute] {
        let (anchorsByID, relations) = resolve(input: input)

        var output: [UUID: any ConnectionRoute] = [:]
        output.reserveCapacity(relations.count)

        for rel in relations {
            guard let a = anchorsByID[rel.a],
                  let b = anchorsByID[rel.b]
            else { continue }

            let start = context.snapPoint(a)
            let end = context.snapPoint(b)
            let corner = preferHorizontalFirst
                ? CGPoint(x: end.x, y: start.y)
                : CGPoint(x: start.x, y: end.y)

            output[rel.id] = ManhattanRoute(points: [start, corner, end])
        }

        return output
    }

    private struct Relation {
        let id: UUID
        let a: UUID
        let b: UUID
    }

    private func resolve(
        input: ConnectionInput
    ) -> ([UUID: CGPoint], [Relation]) {
        switch input {
        case .edges(let anchors, let edges):
            let anchorsByID = Dictionary(uniqueKeysWithValues: anchors.map { ($0.id, $0.position) })
            let relations = edges.map { Relation(id: $0.id, a: $0.startID, b: $0.endID) }
            return (anchorsByID, relations)

        case .adjacency(let anchors, let points):
            let anchorsByID = Dictionary(uniqueKeysWithValues: anchors.map { ($0.id, $0.position) })
            var relations: [Relation] = []
            var seen = Set<String>()

            for point in points {
                for otherID in point.connectedIDs {
                    let key = point.id.uuidString < otherID.uuidString
                        ? "\(point.id.uuidString)|\(otherID.uuidString)"
                        : "\(otherID.uuidString)|\(point.id.uuidString)"
                    if seen.contains(key) { continue }
                    seen.insert(key)
                    relations.append(Relation(id: UUID(), a: point.id, b: otherID))
                }
            }
            return (anchorsByID, relations)
        }
    }
}
