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

    func normalize(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionNormalizationContext
    ) -> ConnectionDelta {
        let tracePoints = points.compactMap { $0 as? TraceVertex }
        let traceLinks = links.compactMap { $0 as? TraceSegment }
        guard !tracePoints.isEmpty, !traceLinks.isEmpty else {
            return ConnectionDelta()
        }

        let epsilon = max(0.5 / max(context.magnification, 0.0001), 0.0001)
        let pointsByID = Dictionary(
            uniqueKeysWithValues: tracePoints.map { ($0.id, context.snapPoint($0.position)) }
        )
        let pointsByObject = Dictionary(
            uniqueKeysWithValues: tracePoints.map { ($0.id, $0 as any ConnectionPoint) }
        )
        let originalLinksByID = Dictionary(uniqueKeysWithValues: traceLinks.map { ($0.id, $0) })
        let preferredIDs = Set(originalLinksByID.keys)

        var state = TraceNormalizationState(
            pointsByID: pointsByID,
            pointsByObject: pointsByObject,
            links: traceLinks,
            removedPointIDs: [],
            removedLinkIDs: [],
            epsilon: epsilon,
            preferredIDs: preferredIDs
        )
        TraceMergeCoincidentRule().apply(to: &state)
        TraceSplitEdgesAtPassingVerticesRule().apply(to: &state)
        TraceCollapseLinearRunsRule().apply(to: &state)
        TraceRemoveIsolatedFreeVerticesRule().apply(to: &state)

        let finalIDs = Set(state.links.map { $0.id })
        var removedLinkIDs = state.removedLinkIDs
        removedLinkIDs.formUnion(Set(originalLinksByID.keys).subtracting(finalIDs))

        var updatedLinks: [TraceSegment] = []
        var addedLinks: [TraceSegment] = []
        for link in state.links {
            if let original = originalLinksByID[link.id] {
                if original.startID != link.startID
                    || original.endID != link.endID
                    || original.width != link.width
                    || original.layerId != link.layerId {
                    updatedLinks.append(link)
                }
            } else {
                addedLinks.append(link)
            }
        }

        let removedPointIDs = state.removedPointIDs
        if removedPointIDs.isEmpty
            && removedLinkIDs.isEmpty
            && updatedLinks.isEmpty
            && addedLinks.isEmpty {
            return ConnectionDelta()
        }

        return ConnectionDelta(
            removedPointIDs: removedPointIDs,
            updatedPoints: [],
            addedPoints: [],
            removedLinkIDs: removedLinkIDs,
            updatedLinks: updatedLinks,
            addedLinks: addedLinks
        )
    }

    func route(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let dx = abs(delta.x)
        let dy = abs(delta.y)

        if dx < 1e-6 || dy < 1e-6 || abs(dx - dy) < 1e-6 {
            return [start, end]
        }

        let sx = delta.x.sign()
        let sy = delta.y.sign()

        let horizontalFirst = preferHorizontalFirst ? (dx >= dy) : (dy < dx)
        if horizontalFirst {
            let leg = dx - dy
            let mid = CGPoint(x: start.x + leg * sx, y: start.y)
            return [start, mid, end]
        }

        let leg = dy - dx
        let mid = CGPoint(x: start.x, y: start.y + leg * sy)
        return [start, mid, end]
    }

}

private extension CGFloat {
    func sign() -> CGFloat {
        (self > 0) ? 1 : ((self < 0) ? -1 : 0)
    }
}
