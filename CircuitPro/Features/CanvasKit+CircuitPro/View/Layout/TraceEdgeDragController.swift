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

        let links = layerSegments.map { $0 as any ConnectionLink }
        let startIncidents = ConnectionInteractionSupport.incidents(
            at: startID, excluding: draggedID, in: links)
        let endIncidents = ConnectionInteractionSupport.incidents(
            at: endID, excluding: draggedID, in: links)

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

        if !startIncidents.isEmpty,
            endIncidents.isEmpty
        {
            if let collapsed = solveOneSidedAxisDiagonalAxisChain(
                junctionID: startID,
                freeID: endID,
                currentJunction: positions[startID] ?? translatedStart,
                currentFreePoint: positions[endID] ?? translatedEnd,
                junctionIncidents: startIncidents,
                allLinks: links,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedOrientation: orientations[draggedID]
            ) {
                for (id, point) in collapsed {
                    positions[id] = point
                }
                return resolvedPositions(
                    positions: positions,
                    originalPositions: originalPositions
                )
            }

            positions[startID] = resolveEndpoint(
                id: startID,
                currentPos: positions[startID] ?? translatedStart,
                currentOtherEnd: positions[endID] ?? translatedEnd,
                junctionIncidents: startIncidents,
                allLinks: links,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedOrientation: orientations[draggedID],
                fixedPointIDs: fixedPointIDs
            )
            collapseImmediateRunIfDirect(
                from: startID,
                junctionIncidents: startIncidents,
                allLinks: links,
                positions: &positions,
                originalPositions: originalPositions
            )
            return resolvedPositions(
                positions: positions,
                originalPositions: originalPositions
            )
        }

        if !endIncidents.isEmpty,
            startIncidents.isEmpty
        {
            if let collapsed = solveOneSidedAxisDiagonalAxisChain(
                junctionID: endID,
                freeID: startID,
                currentJunction: positions[endID] ?? translatedEnd,
                currentFreePoint: positions[startID] ?? translatedStart,
                junctionIncidents: endIncidents,
                allLinks: links,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedOrientation: orientations[draggedID]
            ) {
                for (id, point) in collapsed {
                    positions[id] = point
                }
                return resolvedPositions(
                    positions: positions,
                    originalPositions: originalPositions
                )
            }

            positions[endID] = resolveEndpoint(
                id: endID,
                currentPos: positions[endID] ?? translatedEnd,
                currentOtherEnd: positions[startID] ?? translatedStart,
                junctionIncidents: endIncidents,
                allLinks: links,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedOrientation: orientations[draggedID],
                fixedPointIDs: fixedPointIDs
            )
            collapseImmediateRunIfDirect(
                from: endID,
                junctionIncidents: endIncidents,
                allLinks: links,
                positions: &positions,
                originalPositions: originalPositions
            )
            return resolvedPositions(
                positions: positions,
                originalPositions: originalPositions
            )
        }

        if let resolved = solveTwoSidedAxisSupports(
            startID: startID,
            endID: endID,
            translatedStart: translatedStart,
            translatedEnd: translatedEnd,
            startIncidents: startIncidents,
            endIncidents: endIncidents,
            allLinks: links,
            originalPositions: originalPositions,
            orientations: orientations,
            fixedPointIDs: fixedPointIDs
        ) {
            for (id, point) in resolved {
                positions[id] = point
            }
            return resolvedPositions(
                positions: positions,
                originalPositions: originalPositions
            )
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
                allLinks: links,
                positions: positions,
                originalPositions: originalPositions,
                orientations: orientations,
                fixedPointIDs: fixedPointIDs
            )
            || hasEndpointCrossedSupport(
                endpointID: endID,
                junctionIncidents: endIncidents,
                allLinks: links,
                positions: positions,
                originalPositions: originalPositions,
                orientations: orientations,
                fixedPointIDs: fixedPointIDs
            )
            || ConnectionInteractionSupport.draggedSpanHasInverted(
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
            allLinks: links,
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
                allLinks: links,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedOrientation: orientations[draggedID],
                fixedPointIDs: fixedPointIDs
            )
        }

        if hasEndpointCrossedSupport(
            endpointID: endID,
            junctionIncidents: endIncidents,
            allLinks: links,
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
                allLinks: links,
                originalPositions: originalPositions,
                orientations: orientations,
                draggedOrientation: orientations[draggedID],
                fixedPointIDs: fixedPointIDs
            )
        }

        return resolvedPositions(
            positions: positions,
            originalPositions: originalPositions
        )
    }

    private static func resolvedPositions(
        positions: [UUID: CGPoint],
        originalPositions: [UUID: CGPoint]
    ) -> [UUID: CGPoint] {
        var result: [UUID: CGPoint] = [:]
        for (id, position) in positions {
            guard let original = originalPositions[id], original != position else { continue }
            result[id] = position
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
        startIncidents: [any ConnectionLink],
        endIncidents: [any ConnectionLink],
        originalPositions: [UUID: CGPoint],
        fixedPointIDs: Set<UUID>
    ) -> [UUID: CGPoint]? {
        guard !fixedPointIDs.contains(startID),
            !fixedPointIDs.contains(endID),
            let startIncident = ConnectionInteractionSupport.prioritizedIncident(
                for: startID,
                in: startIncidents,
                fixedPointIDs: fixedPointIDs
            ),
            let endIncident = ConnectionInteractionSupport.prioritizedIncident(
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
        let startOriginalOrientation = ConnectionInteractionSupport.classifyOrientation(
            from: startAnchor, to: startPos)
        let endOriginalOrientation = ConnectionInteractionSupport.classifyOrientation(
            from: endAnchor, to: endPos)

        var bestPositive: JointCandidate?
        var bestPositiveSpan = CGFloat.infinity
        var bestPositiveAxisChanges = Int.max
        var bestCollapse: JointCandidate?
        var bestCollapseAxisChanges = Int.max

        for startOrientation in octilinearOrientations {
            guard
                let startLine = ConnectionInteractionSupport.lineThrough(
                    point: startAnchor, orientation: startOrientation),
                let resolvedStart = ConnectionInteractionSupport.intersect(
                    lineP1: translatedStart,
                    lineP2: translatedEnd,
                    lineQ1: startLine.p1,
                    lineQ2: startLine.p2
                )
            else { continue }

            for endOrientation in octilinearOrientations {
                guard
                    let endLine = ConnectionInteractionSupport.lineThrough(
                        point: endAnchor, orientation: endOrientation),
                    let resolvedEnd = ConnectionInteractionSupport.intersect(
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
                    ConnectionInteractionSupport.orientationChangeCost(
                        from: startOriginalOrientation, to: startOrientation)
                    + ConnectionInteractionSupport.orientationChangeCost(
                        from: endOriginalOrientation, to: endOrientation)

                if span <= 0 {
                    guard
                        let collapse = ConnectionInteractionSupport.intersect(
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
        junctionIncidents: [any ConnectionLink],
        allLinks: [any ConnectionLink],
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
            ConnectionInteractionSupport.fixedFarEndpoint(
                of: a, junction: id, fixedPointIDs: fixedPointIDs)
                && !ConnectionInteractionSupport.fixedFarEndpoint(
                    of: b, junction: id, fixedPointIDs: fixedPointIDs)
        }

        for incident in sortedIncidents {
            let immediateAnchorID = incident.startID == id ? incident.endID : incident.startID
            guard let immediateAnchor = originalPositions[immediateAnchorID] else {
                continue
            }

            let anchor = immediateAnchor
            let candidates = routeJunctionCandidates(from: currentOtherEnd, to: anchor)
            let incidentOrientation =
                orientations[incident.id]
                ?? ConnectionInteractionSupport.classifyOrientation(
                    from: originalJunction, to: anchor)
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

    private static func hasEndpointCrossedSupport(
        endpointID: UUID,
        junctionIncidents: [any ConnectionLink],
        allLinks: [any ConnectionLink],
        positions: [UUID: CGPoint],
        originalPositions: [UUID: CGPoint],
        orientations: [UUID: ConnectionSegmentOrientation],
        fixedPointIDs: Set<UUID>
    ) -> Bool {
        guard
            let incident = ConnectionInteractionSupport.prioritizedIncident(
                for: endpointID,
                in: junctionIncidents,
                fixedPointIDs: fixedPointIDs
            ),
            let current = positions[endpointID],
            let original = originalPositions[endpointID],
            let anchor = ConnectionInteractionSupport.remoteAnchor(
                for: endpointID,
                firstIncident: incident,
                allLinks: allLinks,
                originalPositions: originalPositions
            )
        else { return false }

        let orientation =
            orientations[incident.id]
            ?? ConnectionInteractionSupport.classifyOrientation(from: original, to: anchor)
        guard let direction = orientation.direction else { return false }

        let originalScalar =
            (original.x - anchor.x) * direction.dx + (original.y - anchor.y) * direction.dy
        let currentScalar =
            (current.x - anchor.x) * direction.dx + (current.y - anchor.y) * direction.dy
        return originalScalar > 1e-9 && currentScalar < -1e-9
    }

    private static func solveTwoSidedAxisSupports(
        startID: UUID,
        endID: UUID,
        translatedStart: CGPoint,
        translatedEnd: CGPoint,
        startIncidents: [any ConnectionLink],
        endIncidents: [any ConnectionLink],
        allLinks: [any ConnectionLink],
        originalPositions: [UUID: CGPoint],
        orientations: [UUID: ConnectionSegmentOrientation],
        fixedPointIDs: Set<UUID>
    ) -> [UUID: CGPoint]? {
        guard
            let startIncident = ConnectionInteractionSupport.prioritizedIncident(
                for: startID,
                in: startIncidents,
                fixedPointIDs: fixedPointIDs
            ),
            let endIncident = ConnectionInteractionSupport.prioritizedIncident(
                for: endID,
                in: endIncidents,
                fixedPointIDs: fixedPointIDs
            ),
            let startAnchor = ConnectionInteractionSupport.remoteAnchor(
                for: startID,
                firstIncident: startIncident,
                allLinks: allLinks,
                originalPositions: originalPositions
            ),
            let endAnchor = ConnectionInteractionSupport.remoteAnchor(
                for: endID,
                firstIncident: endIncident,
                allLinks: allLinks,
                originalPositions: originalPositions
            )
        else { return nil }

        let startOrientation =
            orientations[startIncident.id]
            ?? ConnectionInteractionSupport.classifyOrientation(
                from: originalPositions[startID] ?? translatedStart,
                to: startAnchor
            )
        let endOrientation =
            orientations[endIncident.id]
            ?? ConnectionInteractionSupport.classifyOrientation(
                from: originalPositions[endID] ?? translatedEnd,
                to: endAnchor
            )

        guard
            startOrientation == .horizontal || startOrientation == .vertical,
            endOrientation == .horizontal || endOrientation == .vertical,
            let resolvedStart = ConnectionInteractionSupport.projected(
                point: translatedStart,
                ontoLineThrough: startAnchor,
                orientation: startOrientation
            ),
            let resolvedEnd = ConnectionInteractionSupport.projected(
                point: translatedEnd,
                ontoLineThrough: endAnchor,
                orientation: endOrientation
            )
        else { return nil }

        guard
            let originalStart = originalPositions[startID],
            let originalEnd = originalPositions[endID]
        else { return nil }

        let originalDirection = CGVector(
            dx: originalEnd.x - originalStart.x,
            dy: originalEnd.y - originalStart.y
        )
        let resolvedDirection = CGVector(
            dx: resolvedEnd.x - resolvedStart.x,
            dy: resolvedEnd.y - resolvedStart.y
        )
        let span =
            resolvedDirection.dx * originalDirection.dx
            + resolvedDirection.dy * originalDirection.dy

        if span <= 1e-9,
            let startLine = ConnectionInteractionSupport.lineThrough(
                point: startAnchor,
                orientation: startOrientation
            ),
            let endLine = ConnectionInteractionSupport.lineThrough(
                point: endAnchor,
                orientation: endOrientation
            ),
            let collapse = ConnectionInteractionSupport.intersect(
                lineP1: startLine.p1,
                lineP2: startLine.p2,
                lineQ1: endLine.p1,
                lineQ2: endLine.p2
            )
        {
            return [
                startID: collapse,
                endID: collapse,
            ]
        }

        return [
            startID: resolvedStart,
            endID: resolvedEnd,
        ]
    }

    private static func solveOneSidedAxisDiagonalAxisChain(
        junctionID: UUID,
        freeID: UUID,
        currentJunction: CGPoint,
        currentFreePoint: CGPoint,
        junctionIncidents: [any ConnectionLink],
        allLinks: [any ConnectionLink],
        originalPositions: [UUID: CGPoint],
        orientations: [UUID: ConnectionSegmentOrientation],
        draggedOrientation: ConnectionSegmentOrientation?
    ) -> [UUID: CGPoint]? {
        guard
            let draggedOrientation,
            draggedOrientation == .horizontal || draggedOrientation == .vertical,
            junctionIncidents.count == 1,
            let incident = junctionIncidents.first
        else { return nil }

        let middleID = incident.startID == junctionID ? incident.endID : incident.startID
        guard let middlePoint = originalPositions[middleID] else { return nil }

        let downstream = ConnectionInteractionSupport.incidents(
            at: middleID,
            excluding: incident.id,
            in: allLinks
        )
        guard downstream.count == 1,
            let next = downstream.first
        else { return nil }

        let remoteID = next.startID == middleID ? next.endID : next.startID
        guard let remotePoint = originalPositions[remoteID] else { return nil }

        let incidentOrientation =
            orientations[incident.id]
            ?? ConnectionInteractionSupport.classifyOrientation(
                from: originalPositions[junctionID] ?? currentJunction,
                to: middlePoint
            )
        let downstreamOrientation =
            orientations[next.id]
            ?? ConnectionInteractionSupport.classifyOrientation(from: middlePoint, to: remotePoint)

        guard
            incidentOrientation == .diagonalAscending || incidentOrientation == .diagonalDescending,
            downstreamOrientation == .horizontal || downstreamOrientation == .vertical
        else { return nil }

        switch (draggedOrientation, incidentOrientation, downstreamOrientation) {
        case (.vertical, .diagonalAscending, .horizontal):
            let delta = currentFreePoint.x - middlePoint.x
            guard delta >= -1e-9 else { return nil }

            let collapseDelta = (remotePoint.x - middlePoint.x) / 2
            if delta > collapseDelta + 1e-9 {
                let candidates = routeJunctionCandidates(from: currentFreePoint, to: remotePoint)
                guard
                    let resolved = candidates.min(by: {
                        compareCandidates(
                            $0,
                            $1,
                            currentPos: currentJunction,
                            currentOtherEnd: currentFreePoint,
                            anchor: remotePoint,
                            originalJunction: originalPositions[junctionID] ?? currentJunction,
                            draggedOrientation: draggedOrientation,
                            incidentOrientation: downstreamOrientation
                        )
                    })
                else { return nil }

                return [
                    junctionID: resolved,
                    middleID: remotePoint,
                ]
            }

            let clamped = min(
                max(delta, minimumVisibleMiterSpan),
                collapseDelta
            )
            let newJunction = CGPoint(
                x: currentFreePoint.x,
                y: middlePoint.y - clamped
            )
            let newMiddle = CGPoint(
                x: currentFreePoint.x + clamped,
                y: middlePoint.y
            )
            return [
                junctionID: newJunction,
                middleID: newMiddle,
            ]

        case (.horizontal, .diagonalAscending, .vertical):
            let delta = middlePoint.y - currentFreePoint.y
            guard delta >= -1e-9 else { return nil }

            let collapseDelta = (middlePoint.y - remotePoint.y) / 2
            if delta > collapseDelta + 1e-9 {
                let candidates = routeJunctionCandidates(from: currentFreePoint, to: remotePoint)
                guard
                    let resolved = candidates.min(by: {
                        compareCandidates(
                            $0,
                            $1,
                            currentPos: currentJunction,
                            currentOtherEnd: currentFreePoint,
                            anchor: remotePoint,
                            originalJunction: originalPositions[junctionID] ?? currentJunction,
                            draggedOrientation: draggedOrientation,
                            incidentOrientation: downstreamOrientation
                        )
                    })
                else { return nil }

                return [
                    junctionID: resolved,
                    middleID: remotePoint,
                ]
            }

            let clamped = min(
                max(delta, minimumVisibleMiterSpan),
                collapseDelta
            )
            let newJunction = CGPoint(
                x: middlePoint.x + clamped,
                y: currentFreePoint.y
            )
            let newMiddle = CGPoint(
                x: middlePoint.x,
                y: currentFreePoint.y - clamped
            )
            return [
                junctionID: newJunction,
                middleID: newMiddle,
            ]

        default:
            return nil
        }
    }

    private static func collapseImmediateRunIfDirect(
        from junctionID: UUID,
        junctionIncidents: [any ConnectionLink],
        allLinks: [any ConnectionLink],
        positions: inout [UUID: CGPoint],
        originalPositions: [UUID: CGPoint]
    ) {
        guard
            let incident = junctionIncidents.first,
            let junctionPos = positions[junctionID]
        else { return }

        let runPointIDs = linearRunPointIDs(
            from: junctionID,
            firstIncident: incident,
            allLinks: allLinks
        )
        guard runPointIDs.count >= 2,
            let remoteAnchorID = runPointIDs.last,
            let remoteAnchor = originalPositions[remoteAnchorID]
        else { return }

        guard isDirectOctilinear(from: junctionPos, to: remoteAnchor) else { return }

        let immediatePointID = runPointIDs[0]
        positions[immediatePointID] = junctionPos
    }

    private static func linearRunPointIDs(
        from junctionID: UUID,
        firstIncident: any ConnectionLink,
        allLinks: [any ConnectionLink]
    ) -> [UUID] {
        var result: [UUID] = []
        var currentPointID =
            firstIncident.startID == junctionID ? firstIncident.endID : firstIncident.startID
        var previousLinkID = firstIncident.id
        result.append(currentPointID)

        while true {
            let nextLinks = ConnectionInteractionSupport.incidents(
                at: currentPointID,
                excluding: previousLinkID,
                in: allLinks
            )
            guard nextLinks.count == 1 else { return result }
            let next = nextLinks[0]
            currentPointID = next.startID == currentPointID ? next.endID : next.startID
            previousLinkID = next.id
            result.append(currentPointID)
        }
    }

    private static func isDirectOctilinear(from start: CGPoint, to end: CGPoint) -> Bool {
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)
        return dx <= 1e-9 || dy <= 1e-9 || abs(dx - dy) <= 1e-9
    }

    private static let minimumVisibleMiterSpan: CGFloat = 10

    private static let octilinearOrientations: [ConnectionSegmentOrientation] = [
        .horizontal,
        .vertical,
        .diagonalAscending,
        .diagonalDescending,
    ]

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
        let lhsDragged = ConnectionInteractionSupport.classifyOrientation(
            from: lhs, to: currentOtherEnd)
        let rhsDragged = ConnectionInteractionSupport.classifyOrientation(
            from: rhs, to: currentOtherEnd)
        let lhsSupport = ConnectionInteractionSupport.classifyOrientation(from: lhs, to: anchor)
        let rhsSupport = ConnectionInteractionSupport.classifyOrientation(from: rhs, to: anchor)

        let lhsDraggedCost = ConnectionInteractionSupport.orientationChangeCost(
            from: draggedOrientation ?? lhsDragged, to: lhsDragged)
        let rhsDraggedCost = ConnectionInteractionSupport.orientationChangeCost(
            from: draggedOrientation ?? rhsDragged, to: rhsDragged)
        if lhsDraggedCost != rhsDraggedCost {
            return lhsDraggedCost < rhsDraggedCost
        }

        let lhsDraggedFamilyPenalty = draggedFamilyPenalty(
            preferred: draggedOrientation,
            candidate: lhsDragged
        )
        let rhsDraggedFamilyPenalty = draggedFamilyPenalty(
            preferred: draggedOrientation,
            candidate: rhsDragged
        )
        if lhsDraggedFamilyPenalty != rhsDraggedFamilyPenalty {
            return lhsDraggedFamilyPenalty < rhsDraggedFamilyPenalty
        }

        let lhsSupportCost = ConnectionInteractionSupport.orientationChangeCost(
            from: incidentOrientation, to: lhsSupport)
        let rhsSupportCost = ConnectionInteractionSupport.orientationChangeCost(
            from: incidentOrientation, to: rhsSupport)
        if lhsSupportCost != rhsSupportCost {
            return lhsSupportCost < rhsSupportCost
        }

        let lhsCurrentDistance = ConnectionInteractionSupport.squaredDistance(lhs, currentPos)
        let rhsCurrentDistance = ConnectionInteractionSupport.squaredDistance(rhs, currentPos)
        if abs(lhsCurrentDistance - rhsCurrentDistance) > 1e-9 {
            return lhsCurrentDistance < rhsCurrentDistance
        }

        return ConnectionInteractionSupport.squaredDistance(lhs, originalJunction)
            < ConnectionInteractionSupport.squaredDistance(rhs, originalJunction)
    }

    private static func draggedFamilyPenalty(
        preferred: ConnectionSegmentOrientation?,
        candidate: ConnectionSegmentOrientation
    ) -> Int {
        guard let preferred else { return 0 }

        let preferredIsDiagonal =
            preferred == .diagonalAscending || preferred == .diagonalDescending
        let preferredIsAxis = preferred == .horizontal || preferred == .vertical
        let candidateIsDiagonal =
            candidate == .diagonalAscending || candidate == .diagonalDescending
        let candidateIsAxis = candidate == .horizontal || candidate == .vertical

        if preferredIsDiagonal {
            return candidateIsDiagonal ? 0 : 1
        }
        if preferredIsAxis {
            return candidateIsAxis ? 0 : 1
        }
        return 0
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
