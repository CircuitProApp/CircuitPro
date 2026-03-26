import AppKit
import SwiftUI

struct TraceEdgeDragController: ConnectionEdgeDragHandling {
    private var dragState: DragState?

    var isDragging: Bool {
        dragState != nil
    }

    mutating func beginDrag(
        linkID: UUID,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        connectionPoints: [any ConnectionPoint],
        connectionLinks: [any ConnectionLink],
        connectionPointPositionsByID: [UUID: CGPoint],
        baseTolerance: CGFloat,
        liveLinkOrientation: inout [UUID: ConnectionSegmentOrientation]
    ) {
        dragState = nil

        let tolerance = baseTolerance / max(context.magnification, 0.001)
        guard let link = connectionLinks.first(where: { $0.id == linkID }) as? TraceSegment,
            let start = connectionPointPositionsByID[link.startID],
            let end = connectionPointPositionsByID[link.endID]
        else { return }

        let orientations = ConnectionInteractionSupport.buildOrientationMap(
            for: connectionLinks,
            positions: connectionPointPositionsByID,
            tolerance: tolerance,
            mode: .octilinear,
            cache: &liveLinkOrientation
        )

        dragState = DragState(
            edgeID: linkID,
            layerId: link.layerId,
            startID: link.startID,
            endID: link.endID,
            origin: environment.processedMouseLocation ?? context.mouseLocation ?? .zero,
            startPosition: start,
            endPosition: end,
            originalPositions: connectionPointPositionsByID,
            linkOrientation: orientations,
            adjacency: ConnectionInteractionSupport.linkAdjacency(for: connectionLinks),
            linkEndpoints: ConnectionInteractionSupport.linkEndpointMap(for: connectionLinks),
            fixedPointIDs: ConnectionInteractionSupport.fixedPointIDs(
                in: connectionPoints,
                movablePoint: TraceVertex.self
            )
        )
    }

    mutating func updateDrag(
        delta: CanvasDragDelta,
        itemsBinding: Binding<[any CanvasItem]>,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        baseTolerance: CGFloat
    ) {
        guard var state = dragState else { return }

        let pointer = delta.processedLocation
        let rawDelta = CGVector(
            dx: pointer.x - state.origin.x,
            dy: pointer.y - state.origin.y
        )
        let snapped = context.snapProvider.snap(
            delta: rawDelta,
            context: context,
            environment: environment
        )
        let tolerance = baseTolerance / max(context.magnification, 0.001)

        var items = itemsBinding.wrappedValue
        var orientationCache = state.linkOrientation
        let startOrientation = state.linkOrientation[state.edgeID]
        let endOrientation = state.linkOrientation[state.edgeID]

        _ = Self.detachIfNeeded(
            endpointID: state.startID,
            orientation: startOrientation,
            snapped: snapped,
            tolerance: tolerance,
            state: &state,
            items: &items,
            replacingStart: true,
            liveLinkOrientation: &orientationCache
        )

        _ = Self.detachIfNeeded(
            endpointID: state.endID,
            orientation: endOrientation,
            snapped: snapped,
            tolerance: tolerance,
            state: &state,
            items: &items,
            replacingStart: false,
            liveLinkOrientation: &orientationCache
        )
        state.linkOrientation = orientationCache

        let layerSegments = connectionLinks(in: items, on: state.layerId)
        let positionDeltas = Self.solveDraggedSegment(
            draggedID: state.edgeID,
            startID: state.startID,
            endID: state.endID,
            delta: snapped,
            originalPositions: state.originalPositions,
            layerSegments: layerSegments,
            orientations: state.linkOrientation,
            fixedPointIDs: state.fixedPointIDs
        )

        var newPositions = state.originalPositions
        for (id, pos) in positionDeltas {
            newPositions[id] = pos
        }

        for index in items.indices {
            guard var vertex = items[index] as? TraceVertex,
                let updated = newPositions[vertex.id],
                vertex.position != updated
            else { continue }
            vertex.position = updated
            items[index] = vertex
        }

        itemsBinding.wrappedValue = items
        dragState = state
    }

    mutating func endDrag() -> Bool {
        let wasDragging = dragState != nil
        dragState = nil
        return wasDragging
    }

    private static func detachIfNeeded(
        endpointID: UUID,
        orientation: ConnectionSegmentOrientation?,
        snapped: CGVector,
        tolerance: CGFloat,
        state: inout DragState,
        items: inout [any CanvasItem],
        replacingStart: Bool,
        liveLinkOrientation: inout [UUID: ConnectionSegmentOrientation]
    ) -> Bool {
        guard state.fixedPointIDs.contains(endpointID),
            let orientation
        else { return false }

        let shouldDetach = ConnectionInteractionSupport.shouldDetachFixedEndpoint(
            for: snapped,
            orientation: orientation,
            tolerance: tolerance
        )
        guard shouldDetach,
            let endpointPosition = state.originalPositions[endpointID],
            let edgeIndex = items.firstIndex(where: { $0.id == state.edgeID }),
            let edge = items[edgeIndex] as? TraceSegment
        else { return false }

        let newVertex = TraceVertex(position: endpointPosition, layerId: edge.layerId)
        items.append(newVertex)
        state.originalPositions[newVertex.id] = endpointPosition

        if replacingStart {
            state.startID = newVertex.id
            state.startPosition = endpointPosition
        } else {
            state.endID = newVertex.id
            state.endPosition = endpointPosition
        }

        var updatedEdge = edge
        if updatedEdge.startID == endpointID {
            updatedEdge.startID = newVertex.id
        } else if updatedEdge.endID == endpointID {
            updatedEdge.endID = newVertex.id
        }
        items[edgeIndex] = updatedEdge

        let links = items.compactMap { $0 as? TraceSegment }
        if !ConnectionInteractionSupport.hasLink(
            between: endpointID,
            and: newVertex.id,
            links: links.map { $0 as any ConnectionLink }
        ) {
            items.append(
                TraceSegment(
                    startID: endpointID,
                    endID: newVertex.id,
                    width: edge.width,
                    layerId: edge.layerId
                )
            )
        }

        let updatedLinks = items.compactMap { $0 as? TraceSegment }
        let layerLinks = updatedLinks.filter { $0.layerId == edge.layerId }
        let updatedPositions = Dictionary(
            uniqueKeysWithValues: items.compactMap { $0 as? TraceVertex }.map {
                ($0.id, $0.position)
            }
        )
        state.linkOrientation = ConnectionInteractionSupport.buildOrientationMap(
            for: layerLinks.map { $0 as any ConnectionLink },
            positions: updatedPositions,
            tolerance: tolerance,
            mode: .octilinear,
            cache: &liveLinkOrientation
        )
        state.adjacency = ConnectionInteractionSupport.linkAdjacency(
            for: layerLinks.map { $0 as any ConnectionLink }
        )
        state.linkEndpoints = ConnectionInteractionSupport.linkEndpointMap(
            for: layerLinks.map { $0 as any ConnectionLink }
        )

        return true
    }

    private func connectionLinks(in items: [any CanvasItem], on layerId: UUID) -> [TraceSegment] {
        items.compactMap { $0 as? TraceSegment }.filter { $0.layerId == layerId }
    }

    private static func solveDraggedSegment(
        draggedID: UUID,
        startID: UUID,
        endID: UUID,
        delta: CGVector,
        originalPositions: [UUID: CGPoint],
        layerSegments: [TraceSegment],
        orientations: [UUID: ConnectionSegmentOrientation],
        fixedPointIDs: Set<UUID>
    ) -> [UUID: CGPoint] {
        guard let startPos = originalPositions[startID],
            let endPos = originalPositions[endID]
        else { return [:] }

        let translatedStart = CGPoint(x: startPos.x + delta.dx, y: startPos.y + delta.dy)
        let translatedEnd = CGPoint(x: endPos.x + delta.dx, y: endPos.y + delta.dy)

        let startIncidents = incidents(at: startID, excluding: draggedID, in: layerSegments)
        let endIncidents = incidents(at: endID, excluding: draggedID, in: layerSegments)

        let links = layerSegments.map { $0 as any ConnectionLink }
        let adjacency = ConnectionInteractionSupport.linkAdjacency(for: links)
        let linkEndpoints = ConnectionInteractionSupport.linkEndpointMap(for: links)

        var positions = originalPositions
        var movedIDs: [UUID] = []
        if !fixedPointIDs.contains(startID) {
            positions[startID] = translatedStart
            movedIDs.append(startID)
        }
        if !fixedPointIDs.contains(endID) {
            positions[endID] = translatedEnd
            movedIDs.append(endID)
        }

        ConnectionInteractionSupport.applyConstraints(
            movedIDs: movedIDs,
            positions: &positions,
            originalPositions: originalPositions,
            adjacency: adjacency,
            orientations: orientations,
            linkEndpoints: linkEndpoints,
            fixedPointIDs: fixedPointIDs
        )

        let jointEventTriggered =
            hasEndpointCrossedSupport(
                endpointID: startID,
                junctionIncidents: startIncidents,
                allSegments: layerSegments,
                positions: positions,
                originalPositions: originalPositions,
                orientations: orientations,
                fixedPointIDs: fixedPointIDs
            )
            || hasEndpointCrossedSupport(
                endpointID: endID,
                junctionIncidents: endIncidents,
                allSegments: layerSegments,
                positions: positions,
                originalPositions: originalPositions,
                orientations: orientations,
                fixedPointIDs: fixedPointIDs
            )
            || draggedSpanHasInverted(
                startID: startID,
                endID: endID,
                positions: positions,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedID: draggedID
            )

        if jointEventTriggered,
            let joint = solveJointChain(
                startID: startID,
                endID: endID,
                startPos: startPos,
                endPos: endPos,
                translatedStart: positions[startID] ?? translatedStart,
                translatedEnd: positions[endID] ?? translatedEnd,
                startIncidents: startIncidents,
                endIncidents: endIncidents,
                originalPositions: originalPositions,
                fixedPointIDs: fixedPointIDs
            )
        {
            return joint
        }

        if hasEndpointCrossedSupport(
            endpointID: startID,
            junctionIncidents: startIncidents,
            allSegments: layerSegments,
            positions: positions,
            originalPositions: originalPositions,
            orientations: orientations,
            fixedPointIDs: fixedPointIDs
        ) {
            positions[startID] = resolveEndpoint(
                id: startID,
                currentPos: positions[startID] ?? translatedStart,
                currentOtherEnd: positions[endID] ?? translatedEnd,
                junctionIncidents: startIncidents,
                allSegments: layerSegments,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedOrientation: orientations[draggedID],
                fixedPointIDs: fixedPointIDs
            )
        }

        if hasEndpointCrossedSupport(
            endpointID: endID,
            junctionIncidents: endIncidents,
            allSegments: layerSegments,
            positions: positions,
            originalPositions: originalPositions,
            orientations: orientations,
            fixedPointIDs: fixedPointIDs
        ) {
            positions[endID] = resolveEndpoint(
                id: endID,
                currentPos: positions[endID] ?? translatedEnd,
                currentOtherEnd: positions[startID] ?? translatedStart,
                junctionIncidents: endIncidents,
                allSegments: layerSegments,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedOrientation: orientations[draggedID],
                fixedPointIDs: fixedPointIDs
            )
        }

        var result: [UUID: CGPoint] = [:]
        if let resolvedStart = positions[startID], resolvedStart != startPos {
            result[startID] = resolvedStart
        }
        if let resolvedEnd = positions[endID], resolvedEnd != endPos {
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
        currentPos: CGPoint,
        currentOtherEnd: CGPoint,
        junctionIncidents: [TraceSegment],
        allSegments: [TraceSegment],
        originalPositions: [UUID: CGPoint],
        orientations: [UUID: ConnectionSegmentOrientation],
        draggedOrientation: ConnectionSegmentOrientation?,
        fixedPointIDs: Set<UUID>
    ) -> CGPoint {
        if fixedPointIDs.contains(id) {
            return originalPositions[id] ?? currentPos
        }
        guard !junctionIncidents.isEmpty else {
            return currentPos
        }

        let originalJunction = originalPositions[id] ?? currentPos
        let sortedIncidents = junctionIncidents.sorted { a, b in
            fixedFarEndpoint(of: a, junction: id, fixedPointIDs: fixedPointIDs)
                && !fixedFarEndpoint(of: b, junction: id, fixedPointIDs: fixedPointIDs)
        }

        for incident in sortedIncidents {
            let anchorID = incident.startID == id ? incident.endID : incident.startID
            guard let anchor = originalPositions[anchorID] else {
                continue
            }

            let candidates = routeJunctionCandidates(
                from: currentOtherEnd,
                to: anchor
            )
            let incidentOrientation =
                orientations[incident.id]
                ?? classifyOrientation(from: originalJunction, to: anchor)
            if let best = candidates.min(by: {
                compareCandidates(
                    $0,
                    $1,
                    currentPos: currentPos,
                    currentOtherEnd: currentOtherEnd,
                    anchor: anchor,
                    originalJunction: originalJunction,
                    draggedOrientation: draggedOrientation,
                    incidentOrientation: incidentOrientation
                )
            }) {
                return best
            }
        }

        return currentPos
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

    private static func remoteAnchor(
        for junctionID: UUID,
        firstIncident: TraceSegment,
        allSegments: [TraceSegment],
        originalPositions: [UUID: CGPoint]
    ) -> CGPoint? {
        var currentPointID =
            firstIncident.startID == junctionID ? firstIncident.endID : firstIncident.startID
        var previousSegmentID = firstIncident.id

        while true {
            let nextSegments = incidents(
                at: currentPointID,
                excluding: previousSegmentID,
                in: allSegments
            )

            if nextSegments.count != 1 {
                return originalPositions[currentPointID]
            }

            let next = nextSegments[0]
            currentPointID =
                next.startID == currentPointID ? next.endID : next.startID
            previousSegmentID = next.id
        }
    }

    private static func routeJunctionCandidates(
        from start: CGPoint,
        to end: CGPoint
    ) -> [CGPoint] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let absDX = abs(dx)
        let absDY = abs(dy)

        if absDX < 1e-6 || absDY < 1e-6 || abs(absDX - absDY) < 1e-6 {
            return [end]
        }

        let sx = dx.sign()
        let sy = dy.sign()

        if absDX >= absDY {
            let leg = absDX - absDY
            let horizontalFirst = CGPoint(x: start.x + leg * sx, y: start.y)
            let diagonalFirst = CGPoint(x: end.x - leg * sx, y: end.y)
            return uniquePoints([horizontalFirst, diagonalFirst])
        }

        let leg = absDY - absDX
        let verticalFirst = CGPoint(x: start.x, y: start.y + leg * sy)
        let diagonalFirst = CGPoint(x: end.x, y: end.y - leg * sy)
        return uniquePoints([verticalFirst, diagonalFirst])
    }

    private static func uniquePoints(_ points: [CGPoint]) -> [CGPoint] {
        var unique: [CGPoint] = []
        for point in points {
            if unique.contains(where: {
                abs($0.x - point.x) <= 1e-9 && abs($0.y - point.y) <= 1e-9
            }) {
                continue
            }
            unique.append(point)
        }
        return unique
    }

    private static func hasEndpointCrossedSupport(
        endpointID: UUID,
        junctionIncidents: [TraceSegment],
        allSegments: [TraceSegment],
        positions: [UUID: CGPoint],
        originalPositions: [UUID: CGPoint],
        orientations: [UUID: ConnectionSegmentOrientation],
        fixedPointIDs: Set<UUID>
    ) -> Bool {
        guard
            let incident = prioritizedIncident(
                for: endpointID,
                in: junctionIncidents,
                fixedPointIDs: fixedPointIDs
            ),
            let current = positions[endpointID],
            let original = originalPositions[endpointID],
            let anchor = remoteAnchor(
                for: endpointID,
                firstIncident: incident,
                allSegments: allSegments,
                originalPositions: originalPositions
            )
        else { return false }

        let orientation =
            orientations[incident.id] ?? classifyOrientation(from: original, to: anchor)
        guard let direction = orientation.direction else { return false }

        let originalScalar =
            (original.x - anchor.x) * direction.dx + (original.y - anchor.y) * direction.dy
        let currentScalar =
            (current.x - anchor.x) * direction.dx + (current.y - anchor.y) * direction.dy
        return originalScalar > 1e-9 && currentScalar < -1e-9
    }

    private static func draggedSpanHasInverted(
        startID: UUID,
        endID: UUID,
        positions: [UUID: CGPoint],
        originalPositions: [UUID: CGPoint],
        orientations: [UUID: ConnectionSegmentOrientation],
        draggedID: UUID
    ) -> Bool {
        guard let start = positions[startID],
            let end = positions[endID],
            let originalStart = originalPositions[startID],
            let originalEnd = originalPositions[endID]
        else { return false }

        let direction =
            orientations[draggedID]?.direction
            ?? classifyOrientation(from: originalStart, to: originalEnd).direction
        guard let direction else { return false }

        let span = (end.x - start.x) * direction.dx + (end.y - start.y) * direction.dy
        return span < -1e-9
    }

    private static func compareCandidates(
        _ lhs: CGPoint,
        _ rhs: CGPoint,
        currentPos: CGPoint,
        currentOtherEnd: CGPoint,
        anchor: CGPoint,
        originalJunction: CGPoint,
        draggedOrientation: ConnectionSegmentOrientation?,
        incidentOrientation: ConnectionSegmentOrientation
    ) -> Bool {
        let lhsDragged = classifyOrientation(from: lhs, to: currentOtherEnd)
        let rhsDragged = classifyOrientation(from: rhs, to: currentOtherEnd)
        let lhsSupport = classifyOrientation(from: lhs, to: anchor)
        let rhsSupport = classifyOrientation(from: rhs, to: anchor)

        let lhsDraggedCost = orientationChangeCost(
            from: draggedOrientation ?? lhsDragged,
            to: lhsDragged
        )
        let rhsDraggedCost = orientationChangeCost(
            from: draggedOrientation ?? rhsDragged,
            to: rhsDragged
        )
        if lhsDraggedCost != rhsDraggedCost {
            return lhsDraggedCost < rhsDraggedCost
        }

        let lhsSupportCost = orientationChangeCost(from: incidentOrientation, to: lhsSupport)
        let rhsSupportCost = orientationChangeCost(from: incidentOrientation, to: rhsSupport)
        if lhsSupportCost != rhsSupportCost {
            return lhsSupportCost < rhsSupportCost
        }

        let lhsCurrentDistance = squaredDistance(lhs, currentPos)
        let rhsCurrentDistance = squaredDistance(rhs, currentPos)
        if abs(lhsCurrentDistance - rhsCurrentDistance) > 1e-9 {
            return lhsCurrentDistance < rhsCurrentDistance
        }

        return squaredDistance(lhs, originalJunction) < squaredDistance(rhs, originalJunction)
    }

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

    private struct DragState {
        let edgeID: UUID
        let layerId: UUID
        var startID: UUID
        var endID: UUID
        let origin: CGPoint
        var startPosition: CGPoint
        var endPosition: CGPoint
        var originalPositions: [UUID: CGPoint]
        var linkOrientation: [UUID: ConnectionSegmentOrientation]
        var adjacency: [UUID: [UUID]]
        var linkEndpoints: [UUID: (UUID, UUID)]
        var fixedPointIDs: Set<UUID>
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
