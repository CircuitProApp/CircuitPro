import CoreGraphics
import Foundation

struct ManhattanRoute: ConnectionRoute {
    let points: [CGPoint]
}

struct WireEngine: ConnectionEngine {
    var preferHorizontalFirst: Bool = true

    private var normalizationRules: [NormalizationRule] {
        [
            SplitDiagonalLinksRule(preferHorizontalFirst: preferHorizontalFirst),
            MergeCoincidentRule(),
            SplitEdgesAtPassingVerticesRule(),
            CollapseLinearRunsRule(),
            RemoveIsolatedFreeVerticesRule(),
            AssignClusterIDsRule(),
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
            output[link.id] = ManhattanRoute(points: [start, end])
        }

        return output
    }

    func normalize(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionNormalizationContext
    ) -> ConnectionDelta {
        let epsilon = max(0.5 / max(context.magnification, 0.0001), 0.0001)
        var pointsByID = Dictionary(
            uniqueKeysWithValues: points.map { ($0.id, context.snapPoint($0.position)) }
        )
        let pointsByObject = Dictionary(
            uniqueKeysWithValues: points.map { ($0.id, $0) }
        )
        let originalLinksByID = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })
        let preferredIDs = Set(originalLinksByID.keys)

        var state = NormalizationState(
            pointsByID: pointsByID,
            pointsByObject: pointsByObject,
            links: links.map { WireSegment(id: $0.id, startID: $0.startID, endID: $0.endID) },
            addedPoints: [],
            removedPointIDs: [],
            removedLinkIDs: [],
            epsilon: epsilon,
            preferredIDs: preferredIDs
        )

        for rule in normalizationRules {
            rule.apply(to: &state)
        }

        pointsByID = state.pointsByID
        let finalIDs = Set(state.links.map { $0.id })
        var removedLinkIDs = state.removedLinkIDs
        removedLinkIDs.formUnion(Set(originalLinksByID.keys).subtracting(finalIDs))

        var updatedLinks: [any CanvasItem & ConnectionLink] = []
        var addedLinksOut: [any CanvasItem & ConnectionLink] = []
        for link in state.links {
            if let original = originalLinksByID[link.id] {
                if original.startID != link.startID || original.endID != link.endID {
                    updatedLinks.append(link)
                }
            } else {
                addedLinksOut.append(link)
            }
        }

        let removedPointIDs = state.removedPointIDs
        let addedPointsOut = state.addedPoints.filter { !removedPointIDs.contains($0.id) }
        if removedPointIDs.isEmpty
            && removedLinkIDs.isEmpty
            && updatedLinks.isEmpty
            && addedLinksOut.isEmpty
            && addedPointsOut.isEmpty {
            return ConnectionDelta()
        }

        return ConnectionDelta(
            removedPointIDs: removedPointIDs,
            updatedPoints: [],
            addedPoints: addedPointsOut,
            removedLinkIDs: removedLinkIDs,
            updatedLinks: updatedLinks,
            addedLinks: addedLinksOut
        )
    }
}
