import CoreGraphics
import Foundation

/// Resolves a dragged trace segment by rerouting the local two-segment chain between
/// the two far endpoints using the same octilinear routing rule as `TraceTool`.
///
/// The important invariant is topological, not orientation-specific: whichever side
/// of the junction the dragged segment occupied before the drag, it keeps occupying
/// that side while the bend is recomputed from the translated far endpoint.
enum TraceSegmentDragSolver {

    static func solve(
        draggedID: UUID,
        startID: UUID,
        endID: UUID,
        delta: CGVector,
        originalPositions: [UUID: CGPoint],
        layerSegments: [TraceSegment],
        orientations: [UUID: ConnectionSegmentOrientation],
        fixedPointIDs: Set<UUID>
    ) -> [UUID: CGPoint] {
        _ = draggedID
        _ = orientations

        guard let startPos = originalPositions[startID],
            let endPos = originalPositions[endID]
        else { return [:] }

        let translatedStart = CGPoint(x: startPos.x + delta.dx, y: startPos.y + delta.dy)
        let translatedEnd = CGPoint(x: endPos.x + delta.dx, y: endPos.y + delta.dy)

        let startIncidents = incidents(at: startID, excluding: draggedID, in: layerSegments)
        let endIncidents = incidents(at: endID, excluding: draggedID, in: layerSegments)

        if let joint = solveJointChain(
            startID: startID,
            endID: endID,
            startPos: startPos,
            endPos: endPos,
            translatedStart: translatedStart,
            translatedEnd: translatedEnd,
            startIncidents: startIncidents,
            endIncidents: endIncidents,
            originalPositions: originalPositions,
            fixedPointIDs: fixedPointIDs
        ) {
            return joint
        }

        var result: [UUID: CGPoint] = [:]

        let resolvedStart = resolveEndpoint(
            id: startID,
            translatedPos: translatedStart,
            translatedOtherEnd: translatedEnd,
            originalOtherEnd: endPos,
            junctionIncidents: startIncidents,
            originalPositions: originalPositions,
            fixedPointIDs: fixedPointIDs
        )
        if resolvedStart != startPos {
            result[startID] = resolvedStart
        }

        let resolvedEnd = resolveEndpoint(
            id: endID,
            translatedPos: translatedEnd,
            translatedOtherEnd: translatedStart,
            originalOtherEnd: startPos,
            junctionIncidents: endIncidents,
            originalPositions: originalPositions,
            fixedPointIDs: fixedPointIDs
        )
        if resolvedEnd != endPos {
            result[endID] = resolvedEnd
        }

        return result
    }

    private static func solveJointChain(
        startID: UUID,
        endID: UUID,
        startPos: CGPoint,
        endPos: CGPoint,
        translatedStart: CGPoint,
        translatedEnd: CGPoint,
        startIncidents: [TraceSegment],
        endIncidents: [TraceSegment],
        originalPositions: [UUID: CGPoint],
        fixedPointIDs: Set<UUID>
    ) -> [UUID: CGPoint]? {
        guard !fixedPointIDs.contains(startID),
            !fixedPointIDs.contains(endID),
            let startIncident = prioritizedIncident(
                for: startID,
                in: startIncidents,
                fixedPointIDs: fixedPointIDs
            ),
            let endIncident = prioritizedIncident(
                for: endID,
                in: endIncidents,
                fixedPointIDs: fixedPointIDs
            )
        else { return nil }

        let startAnchorID =
            startIncident.startID == startID ? startIncident.endID : startIncident.startID
        let endAnchorID = endIncident.startID == endID ? endIncident.endID : endIncident.startID
        guard let startAnchor = originalPositions[startAnchorID],
            let endAnchor = originalPositions[endAnchorID]
        else { return nil }

        let originalDirection = CGVector(dx: endPos.x - startPos.x, dy: endPos.y - startPos.y)
        let startOriginalOrientation = classifyOrientation(from: startAnchor, to: startPos)
        let endOriginalOrientation = classifyOrientation(from: endAnchor, to: endPos)

        var bestPositive: JointCandidate?
        var bestPositiveSpan = CGFloat.infinity
        var bestPositiveAxisChanges = Int.max
        var bestCollapse: JointCandidate?
        var bestCollapseAxisChanges = Int.max

        for startOrientation in octilinearOrientations {
            guard let startLine = lineThrough(point: startAnchor, orientation: startOrientation),
                let resolvedStart = intersect(
                    lineP1: translatedStart,
                    lineP2: translatedEnd,
                    lineQ1: startLine.p1,
                    lineQ2: startLine.p2
                )
            else { continue }

            for endOrientation in octilinearOrientations {
                guard let endLine = lineThrough(point: endAnchor, orientation: endOrientation),
                    let resolvedEnd = intersect(
                        lineP1: translatedStart,
                        lineP2: translatedEnd,
                        lineQ1: endLine.p1,
                        lineQ2: endLine.p2
                    )
                else { continue }

                let resolvedDirection = CGVector(
                    dx: resolvedEnd.x - resolvedStart.x,
                    dy: resolvedEnd.y - resolvedStart.y
                )
                let span =
                    resolvedDirection.dx * originalDirection.dx
                    + resolvedDirection.dy * originalDirection.dy
                let axisChanges =
                    orientationChangeCost(from: startOriginalOrientation, to: startOrientation)
                    + orientationChangeCost(from: endOriginalOrientation, to: endOrientation)

                if span <= 0 {
                    guard
                        let collapse = intersect(
                            lineP1: startLine.p1,
                            lineP2: startLine.p2,
                            lineQ1: endLine.p1,
                            lineQ2: endLine.p2
                        )
                    else { continue }

                    if bestCollapse == nil || axisChanges < bestCollapseAxisChanges {
                        bestCollapse = JointCandidate(start: collapse, end: collapse)
                        bestCollapseAxisChanges = axisChanges
                    }
                    continue
                }

                if span < bestPositiveSpan
                    || (abs(span - bestPositiveSpan) <= 1e-9
                        && axisChanges < bestPositiveAxisChanges)
                {
                    bestPositive = JointCandidate(start: resolvedStart, end: resolvedEnd)
                    bestPositiveSpan = span
                    bestPositiveAxisChanges = axisChanges
                }
            }
        }

        guard let chosen = bestCollapse ?? bestPositive else { return nil }

        var result: [UUID: CGPoint] = [:]
        if chosen.start != startPos {
            result[startID] = chosen.start
        }
        if chosen.end != endPos {
            result[endID] = chosen.end
        }
        return result
    }

    private static func resolveEndpoint(
        id: UUID,
        translatedPos: CGPoint,
        translatedOtherEnd: CGPoint,
        originalOtherEnd: CGPoint,
        junctionIncidents: [TraceSegment],
        originalPositions: [UUID: CGPoint],
        fixedPointIDs: Set<UUID>
    ) -> CGPoint {
        if fixedPointIDs.contains(id) {
            return originalPositions[id] ?? translatedPos
        }
        guard !junctionIncidents.isEmpty else {
            return translatedPos
        }

        let originalJunction = originalPositions[id] ?? translatedPos
        let sortedIncidents = junctionIncidents.sorted { a, b in
            fixedFarEndpoint(of: a, junction: id, fixedPointIDs: fixedPointIDs)
                && !fixedFarEndpoint(of: b, junction: id, fixedPointIDs: fixedPointIDs)
        }

        for incident in sortedIncidents {
            let anchorID = incident.startID == id ? incident.endID : incident.startID
            guard let anchor = originalPositions[anchorID] else {
                continue
            }

            let draggedFirst = draggedSegmentIsFirstLeg(
                anchor: anchor,
                originalDraggedOtherEnd: originalOtherEnd,
                originalJunction: originalJunction
            )

            let path =
                draggedFirst
                ? routePoints(from: translatedOtherEnd, to: anchor)
                : routePoints(from: anchor, to: translatedOtherEnd)

            return resolvedJunction(from: path, draggedSegmentIsFirst: draggedFirst)
        }

        return translatedPos
    }

    private static func draggedSegmentIsFirstLeg(
        anchor: CGPoint,
        originalDraggedOtherEnd: CGPoint,
        originalJunction: CGPoint
    ) -> Bool {
        let incidentFirstPath = routePoints(from: anchor, to: originalDraggedOtherEnd)
        let incidentFirstJunction = resolvedJunction(
            from: incidentFirstPath,
            draggedSegmentIsFirst: false
        )

        let draggedFirstPath = routePoints(from: originalDraggedOtherEnd, to: anchor)
        let draggedFirstJunction = resolvedJunction(
            from: draggedFirstPath,
            draggedSegmentIsFirst: true
        )

        let incidentFirstDistance = squaredDistance(incidentFirstJunction, originalJunction)
        let draggedFirstDistance = squaredDistance(draggedFirstJunction, originalJunction)

        return draggedFirstDistance < incidentFirstDistance
    }

    private static func resolvedJunction(
        from path: [CGPoint],
        draggedSegmentIsFirst: Bool
    ) -> CGPoint {
        guard let first = path.first, let last = path.last else {
            return .zero
        }
        if path.count <= 2 {
            return draggedSegmentIsFirst ? last : first
        }
        return draggedSegmentIsFirst ? path[1] : path[path.count - 2]
    }

    private static func routePoints(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let dx = abs(delta.x)
        let dy = abs(delta.y)

        if dx < 1e-6 || dy < 1e-6 || abs(dx - dy) < 1e-6 {
            return [start, end]
        }

        let sx = delta.x.sign()
        let sy = delta.y.sign()

        if dx >= dy {
            let leg = dx - dy
            let mid = CGPoint(x: start.x + leg * sx, y: start.y)
            return [start, mid, end]
        }

        let leg = dy - dx
        let mid = CGPoint(x: start.x, y: start.y + leg * sy)
        return [start, mid, end]
    }

    private static func incidents(
        at id: UUID,
        excluding excludedID: UUID,
        in segments: [TraceSegment]
    ) -> [TraceSegment] {
        segments.filter { $0.id != excludedID && ($0.startID == id || $0.endID == id) }
    }

    private static func fixedFarEndpoint(
        of segment: TraceSegment,
        junction: UUID,
        fixedPointIDs: Set<UUID>
    ) -> Bool {
        let farID = segment.startID == junction ? segment.endID : segment.startID
        return fixedPointIDs.contains(farID)
    }

    private static func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    private static let octilinearOrientations: [ConnectionSegmentOrientation] = [
        .horizontal,
        .vertical,
        .diagonalAscending,
        .diagonalDescending,
    ]

    private static func prioritizedIncident(
        for junction: UUID,
        in segments: [TraceSegment],
        fixedPointIDs: Set<UUID>
    ) -> TraceSegment? {
        segments.sorted { a, b in
            fixedFarEndpoint(of: a, junction: junction, fixedPointIDs: fixedPointIDs)
                && !fixedFarEndpoint(of: b, junction: junction, fixedPointIDs: fixedPointIDs)
        }.first
    }

    private static func intersect(
        lineP1 p1: CGPoint,
        lineP2 p2: CGPoint,
        lineQ1 q1: CGPoint,
        lineQ2 q2: CGPoint
    ) -> CGPoint? {
        let d1 = CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
        let d2 = CGVector(dx: q2.x - q1.x, dy: q2.y - q1.y)
        let det = d1.dx * (-d2.dy) + d2.dx * d1.dy
        guard abs(det) > 1e-9 else { return nil }
        let rx = q1.x - p1.x
        let ry = q1.y - p1.y
        let t = (rx * (-d2.dy) + d2.dx * ry) / det
        return CGPoint(x: p1.x + t * d1.dx, y: p1.y + t * d1.dy)
    }

    private static func lineThrough(
        point: CGPoint,
        orientation: ConnectionSegmentOrientation
    ) -> (p1: CGPoint, p2: CGPoint)? {
        switch orientation {
        case .horizontal:
            return (point, CGPoint(x: point.x + 1, y: point.y))
        case .vertical:
            return (point, CGPoint(x: point.x, y: point.y + 1))
        case .diagonalAscending:
            return (point, CGPoint(x: point.x + 1, y: point.y + 1))
        case .diagonalDescending:
            return (point, CGPoint(x: point.x + 1, y: point.y - 1))
        default:
            return nil
        }
    }

    private static func classifyOrientation(
        from start: CGPoint,
        to end: CGPoint
    ) -> ConnectionSegmentOrientation {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if abs(dx) <= 1e-9 { return .vertical }
        if abs(dy) <= 1e-9 { return .horizontal }
        let sameSign = (dx >= 0 && dy >= 0) || (dx <= 0 && dy <= 0)
        return sameSign ? .diagonalAscending : .diagonalDescending
    }

    private static func orientationChangeCost(
        from original: ConnectionSegmentOrientation,
        to candidate: ConnectionSegmentOrientation
    ) -> Int {
        original == candidate ? 0 : 1
    }

    private struct JointCandidate {
        let start: CGPoint
        let end: CGPoint
    }
}

extension CGFloat {
    fileprivate func sign() -> CGFloat {
        (self > 0) ? 1 : ((self < 0) ? -1 : 0)
    }
}
