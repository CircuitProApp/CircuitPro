import AppKit

struct TraceView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    @CKState private var dragState: DragState?
    @CKState private var liveLinkOrientation: [UUID: ConnectionSegmentOrientation] = [:]

    let traceEngine: TraceEngine

    var body: some CKView {
        let points = connectionPoints
        let links = connectionLinks
        let routingContext = ConnectionRoutingContext { point in
            context.snapProvider.snap(point: point, context: context, environment: environment)
        }
        let routes = traceEngine.routes(points: points, links: links, context: routingContext)

        return CKGroup {
            for trace in links {
                if let path = routePath(for: trace.id, routes: routes) {
                    let showHalo =
                        context.highlightedItemIDs.contains(trace.id)
                        || context.selectedItemIDs.contains(trace.id)
                    let color =
                        context.layers.first { $0.id == trace.layerId }?.color
                        ?? environment.canvasTheme.textColor

                    CKPath(path: path)
                        .stroke(color, width: trace.width)
                        .halo(
                            showHalo ? (color.copy(alpha: 0.35) ?? .clear) : .clear,
                            width: trace.width + 4
                        )
                        .hoverable(trace.id)
                        .selectable(trace.id)
                        .onDragGesture { phase in
                            handleDrag(linkID: trace.id, phase: phase)
                        }
                }
            }
        }
    }

    private func routePath(
        for linkID: UUID,
        routes: [UUID: any ConnectionRoute]
    ) -> CGPath? {
        guard let route = routes[linkID] as? TraceRoute else { return nil }
        guard route.points.count >= 2 else { return nil }

        let path = CGMutablePath()
        path.move(to: route.points[0])
        for point in route.points.dropFirst() {
            path.addLine(to: point)
        }
        return path.isEmpty ? nil : path
    }

    private func handleDrag(linkID: UUID, phase: CanvasDragPhase) {
        switch phase {
        case .began:
            beginDrag(linkID: linkID)
        case .changed(let delta):
            updateDrag(delta: delta)
        case .ended:
            endDrag()
        }
    }

    private func beginDrag(linkID: UUID) {
        dragState = nil

        let tolerance = baseTolerance / max(context.magnification, 0.001)
        var items = context.itemsBinding?.wrappedValue ?? context.items
        guard var link = connectionLinks(in: items).first(where: { $0.id == linkID }) else {
            return
        }

        if splitSharedEndpointsIfNeeded(for: link, items: &items) {
            context.itemsBinding?.wrappedValue = items
            guard let updated = connectionLinks(in: items).first(where: { $0.id == linkID }) else {
                return
            }
            link = updated
        }

        let points = connectionPoints(in: items)
        let pointsByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        guard let start = pointsByID[link.startID],
            let end = pointsByID[link.endID]
        else { return }

        let layerLinks = connectionLinks(in: items, on: link.layerId)
        let links = layerLinks.map { $0 as any ConnectionLink }
        let orientations = ConnectionInteractionSupport.buildOrientationMap(
            for: links,
            positions: pointsByID,
            tolerance: tolerance,
            mode: .octilinear,
            cache: &liveLinkOrientation
        )

        dragState = DragState(
            edgeID: linkID,
            startID: link.startID,
            endID: link.endID,
            origin: environment.processedMouseLocation ?? context.mouseLocation ?? .zero,
            startPosition: start,
            endPosition: end,
            originalPositions: pointsByID,
            linkOrientation: orientations,
            adjacency: ConnectionInteractionSupport.linkAdjacency(for: links),
            linkEndpoints: ConnectionInteractionSupport.linkEndpointMap(for: links),
            fixedPointIDs: ConnectionInteractionSupport.fixedPointIDs(
                in: points,
                movablePoint: TraceVertex.self
            )
        )
    }

    private func updateDrag(delta: CanvasDragDelta) {
        guard var state = dragState,
            let itemsBinding = context.itemsBinding
        else { return }

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

        if detachIfNeeded(
            endpointID: state.startID,
            orientation: state.linkOrientation[state.edgeID],
            snapped: snapped,
            tolerance: tolerance,
            state: &state,
            items: &items,
            replacingStart: true
        ) {
            dragState = state
        }

        if detachIfNeeded(
            endpointID: state.endID,
            orientation: state.linkOrientation[state.edgeID],
            snapped: snapped,
            tolerance: tolerance,
            state: &state,
            items: &items,
            replacingStart: false
        ) {
            dragState = state
        }

        let newStart = CGPoint(
            x: state.startPosition.x + snapped.dx,
            y: state.startPosition.y + snapped.dy
        )
        let newEnd = CGPoint(
            x: state.endPosition.x + snapped.dx,
            y: state.endPosition.y + snapped.dy
        )
        let isStartFixed = state.fixedPointIDs.contains(state.startID)
        let isEndFixed = state.fixedPointIDs.contains(state.endID)

        var newPositions = state.originalPositions
        if !isStartFixed {
            newPositions[state.startID] = newStart
        }
        if !isEndFixed {
            newPositions[state.endID] = newEnd
        }

        ConnectionInteractionSupport.applyConstraints(
            movedIDs: [state.startID, state.endID].filter { !state.fixedPointIDs.contains($0) },
            positions: &newPositions,
            originalPositions: state.originalPositions,
            adjacency: state.adjacency,
            orientations: state.linkOrientation,
            linkEndpoints: state.linkEndpoints,
            fixedPointIDs: state.fixedPointIDs
        )

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

    private func endDrag() {
        guard dragState != nil,
            let itemsBinding = context.itemsBinding
        else {
            dragState = nil
            return
        }

        var items = itemsBinding.wrappedValue
        let points = connectionPoints(in: items)
        let links = connectionLinks(in: items).map { $0 as any ConnectionLink }
        ConnectionInteractionSupport.applyNormalization(
            to: &items,
            engine: traceEngine,
            context: context,
            environment: environment,
            points: points,
            links: links
        )
        itemsBinding.wrappedValue = items
        dragState = nil
    }

    private func detachIfNeeded(
        endpointID: UUID,
        orientation: ConnectionSegmentOrientation?,
        snapped: CGVector,
        tolerance: CGFloat,
        state: inout DragState,
        items: inout [any CanvasItem],
        replacingStart: Bool
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
            uniqueKeysWithValues: connectionPoints(in: items).map { ($0.id, $0.position) }
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

    private var baseTolerance: CGFloat {
        6
    }

    private var connectionPoints: [any ConnectionPoint] {
        connectionPoints(in: context.items)
    }

    private var connectionLinks: [TraceSegment] {
        connectionLinks(in: context.items)
    }

    private func connectionLinks(on layerId: UUID) -> [TraceSegment] {
        connectionLinks(in: context.items, on: layerId)
    }

    private var connectionPointPositionsByID: [UUID: CGPoint] {
        Dictionary(uniqueKeysWithValues: connectionPoints.map { ($0.id, $0.position) })
    }

    private func connectionPoints(in items: [any CanvasItem]) -> [any ConnectionPoint] {
        items.compactMap { $0 as? TraceVertex }
    }

    private func connectionLinks(in items: [any CanvasItem]) -> [TraceSegment] {
        items.compactMap { $0 as? TraceSegment }
    }

    private func connectionLinks(in items: [any CanvasItem], on layerId: UUID) -> [TraceSegment] {
        connectionLinks(in: items).filter { $0.layerId == layerId }
    }

    private func splitSharedEndpointsIfNeeded(
        for link: TraceSegment,
        items: inout [any CanvasItem]
    ) -> Bool {
        var didChange = false
        didChange =
            splitPointIfNeeded(link.startID, layerId: link.layerId, items: &items) || didChange
        didChange =
            splitPointIfNeeded(link.endID, layerId: link.layerId, items: &items) || didChange
        return didChange
    }

    private func splitPointIfNeeded(
        _ pointID: UUID,
        layerId: UUID,
        items: inout [any CanvasItem]
    ) -> Bool {
        let links = items.compactMap { $0 as? TraceSegment }
        let activeLinks = links.filter {
            $0.layerId == layerId && ($0.startID == pointID || $0.endID == pointID)
        }
        let foreignLinks = links.filter {
            $0.layerId != layerId && ($0.startID == pointID || $0.endID == pointID)
        }
        guard !activeLinks.isEmpty,
            !foreignLinks.isEmpty,
            let vertexIndex = items.firstIndex(where: { $0.id == pointID }),
            let vertex = items[vertexIndex] as? TraceVertex
        else { return false }

        let clone = TraceVertex(position: vertex.position, layerId: layerId)
        items.append(clone)

        let activeIDs = Set(activeLinks.map(\.id))
        for index in items.indices {
            guard activeIDs.contains(items[index].id),
                var segment = items[index] as? TraceSegment
            else { continue }
            if segment.startID == pointID {
                segment.startID = clone.id
            }
            if segment.endID == pointID {
                segment.endID = clone.id
            }
            items[index] = segment
        }

        return true
    }

    private struct DragState {
        let edgeID: UUID
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
}
