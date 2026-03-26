import AppKit

struct TraceView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    @CKState private var edgeDragController = TraceEdgeDragController()
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
        guard let route = routes[linkID] as? OctilinearRoute else { return nil }
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
            guard let itemsBinding = context.itemsBinding else { return }
            edgeDragController.updateDrag(
                delta: delta,
                itemsBinding: itemsBinding,
                context: context,
                environment: environment,
                baseTolerance: baseTolerance
            )
        case .ended:
            endDrag()
        }
    }

    private func beginDrag(linkID: UUID) {
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
        let layerLinks = connectionLinks(in: items, on: link.layerId)
        edgeDragController.beginDrag(
            linkID: linkID,
            context: context,
            environment: environment,
            connectionPoints: points,
            connectionLinks: layerLinks.map { $0 as any ConnectionLink },
            connectionPointPositionsByID: pointsByID,
            baseTolerance: baseTolerance,
            liveLinkOrientation: &liveLinkOrientation
        )
    }

    private func endDrag() {
        guard edgeDragController.endDrag(),
            let itemsBinding = context.itemsBinding
        else {
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
}
