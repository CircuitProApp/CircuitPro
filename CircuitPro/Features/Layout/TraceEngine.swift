import CoreGraphics
import Foundation

struct OctilinearRoute: ConnectionRoute {
    let points: [CGPoint]
}

struct TraceEngine: ConnectionEngine {
    var preferHorizontalFirst: Bool = true

    private var normalizationRules: [(inout TraceNormalizationState) -> Void] {
        [
            { TraceAssignVertexLayersRule().apply(to: &$0) },
            {
                MergeCoincidentRule<TraceSegment, TraceVertex>().apply(
                    pointsByID: &$0.pointsByID,
                    pointsByObject: $0.pointsByObject,
                    links: &$0.links,
                    removedPointIDs: &$0.removedPointIDs,
                    removedLinkIDs: &$0.removedLinkIDs,
                    epsilon: $0.epsilon
                )
            },
            {
                SplitEdgesAtPassingVerticesRule<TraceSegment>(
                    shouldSplitThroughPoint: { point, metadata in
                        guard let traceVertex = point as? TraceVertex else { return true }
                        return traceVertex.layerId == metadata.layerId
                    }
                ).apply(
                    pointsByID: $0.pointsByID,
                    pointsByObject: $0.pointsByObject,
                    links: &$0.links,
                    removedLinkIDs: &$0.removedLinkIDs,
                    epsilon: $0.epsilon
                )
            },
            {
                CollapseLinearRunsRule<TraceSegment, TraceVertex>().apply(
                    pointsByID: &$0.pointsByID,
                    pointsByObject: $0.pointsByObject,
                    links: &$0.links,
                    removedPointIDs: &$0.removedPointIDs,
                    removedLinkIDs: &$0.removedLinkIDs,
                    epsilon: $0.epsilon,
                    preferredIDs: $0.preferredIDs
                )
            },
            {
                RemoveIsolatedFreeVerticesRule<TraceVertex, TraceSegment>().apply(
                    pointsByID: &$0.pointsByID,
                    pointsByObject: $0.pointsByObject,
                    links: $0.links,
                    removedPointIDs: &$0.removedPointIDs
                )
            },
        ]
    }

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
            let pathPoints = routePoints(from: start, to: end)
            output[link.id] = OctilinearRoute(points: pathPoints)
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
        let typedPointsByID = Dictionary(
            uniqueKeysWithValues: tracePoints.map { ($0.id, $0) }
        )
        let originalLinksByID = Dictionary(uniqueKeysWithValues: traceLinks.map { ($0.id, $0) })
        let originalPointsByID = typedPointsByID
        let preferredIDs = Set(originalLinksByID.keys)

        var state = TraceNormalizationState(
            pointsByID: pointsByID,
            pointsByObject: pointsByObject,
            typedPointsByID: typedPointsByID,
            links: traceLinks,
            addedPoints: [],
            removedPointIDs: [],
            removedLinkIDs: [],
            epsilon: epsilon,
            preferredIDs: preferredIDs
        )
        for rule in normalizationRules {
            rule(&state)
        }

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
                    || original.layerId != link.layerId
                {
                    updatedLinks.append(link)
                }
            } else {
                addedLinks.append(link)
            }
        }

        var updatedPoints: [TraceVertex] = []
        let addedPoints = state.addedPoints.filter { !state.removedPointIDs.contains($0.id) }
        for (id, point) in state.typedPointsByID {
            guard !state.removedPointIDs.contains(id),
                let original = originalPointsByID[id]
            else { continue }
            if original.position != point.position || original.layerId != point.layerId {
                updatedPoints.append(point)
            }
        }

        let removedPointIDs = state.removedPointIDs
        if removedPointIDs.isEmpty
            && removedLinkIDs.isEmpty
            && updatedPoints.isEmpty
            && addedPoints.isEmpty
            && updatedLinks.isEmpty
            && addedLinks.isEmpty
        {
            return ConnectionDelta()
        }

        return ConnectionDelta(
            removedPointIDs: removedPointIDs,
            updatedPoints: updatedPoints,
            addedPoints: addedPoints,
            removedLinkIDs: removedLinkIDs,
            updatedLinks: updatedLinks,
            addedLinks: addedLinks
        )
    }

    func routePoints(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
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

extension CGFloat {
    fileprivate func sign() -> CGFloat {
        (self > 0) ? 1 : ((self < 0) ? -1 : 0)
    }
}
