import AppKit
import SwiftUI

struct WireView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    @CKState private var edgeDragController = WireEdgeDragController()
    @CKState private var liveLinkOrientation: [UUID: ConnectionSegmentOrientation] = [:]
    @CKState private var globalDragTargetID: UUID?

    private let baseTolerance: CGFloat = 6
    private let engine: any ConnectionEngine

    init(engine: any ConnectionEngine) {
        self.engine = engine
    }

    var wireColor: CKColor {
        CKColor(environment.schematicTheme.wireColor)
    }

    var body: some CKView {
        let routingContext = ConnectionRoutingContext { point in
            context.snapProvider.snap(point: point, context: context, environment: environment)
        }
        let routes = engine.routes(
            points: connectionPoints,
            links: connectionLinks,
            context: routingContext
        )
        let activeLinkIDs = context.selectedItemIDs
            .union(context.highlightedItemIDs)
        CKGroup {
            if !activeLinkIDs.isEmpty {
                CKGroup {
                    for linkID in activeLinkIDs {
                        if let path = routePath(for: linkID, routes: routes) {
                            CKPath(path: path)
                        }
                    }
                }
                .mergePaths()
                .halo(wireColor.haloOpacity(), width: 5)
            }
            for linkID in routes.keys {
                if let path = routePath(for: linkID, routes: routes) {
                    CKPath(path: path)
                        .stroke(wireColor, width: 1)
                        .hoverable(linkID)
                        .selectable(linkID)
                        .onDragGesture { phase in
                            handleDrag(linkID: linkID, phase: phase)
                        }
                }
            }

            let dotPath = junctionDotsPath(
                pointsByID: connectionPointPositionsByID,
                links: connectionLinks,
                dotRadius: 3.0
            )
            if !dotPath.isEmpty {
                CKPath(path: dotPath)
                    .fill(wireColor)
            }
        }
        .onCanvasDrag { phase, renderContext, controller in
            handleGlobalDrag(phase, context: renderContext, controller: controller)
        }
    }

    private func routePath(
        for linkID: UUID,
        routes: [UUID: any ConnectionRoute]
    ) -> CGPath? {
        guard let route = routes[linkID] as? ManhattanRoute else { return nil }
        let points = route.points
        guard points.count >= 2 else { return nil }
        let path = CGMutablePath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path.isEmpty ? nil : path
    }

    private func junctionDotsPath(
        pointsByID: [UUID: CGPoint],
        links: [any ConnectionLink],
        dotRadius: CGFloat
    ) -> CGPath {
        var degreeByID: [UUID: Int] = [:]
        for link in links {
            degreeByID[link.startID, default: 0] += 1
            degreeByID[link.endID, default: 0] += 1
        }

        let path = CGMutablePath()
        for (id, degree) in degreeByID where degree >= 3 {
            guard let position = pointsByID[id] else { continue }
            let rect = CGRect(
                x: position.x - dotRadius,
                y: position.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            path.addEllipse(in: rect)
        }
        return path
    }

    private func handleDrag(linkID: UUID, phase: CanvasDragPhase) {
        switch phase {
        case .began:
            edgeDragController.beginDrag(
                linkID: linkID,
                context: context,
                environment: environment,
                connectionPoints: connectionPoints,
                connectionLinks: connectionLinks,
                connectionPointPositionsByID: connectionPointPositionsByID,
                baseTolerance: baseTolerance,
                liveLinkOrientation: &liveLinkOrientation
            )
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

    private func endDrag() {
        guard edgeDragController.endDrag(),
            let itemsBinding = context.itemsBinding
        else {
            return
        }

        var items = itemsBinding.wrappedValue
        let points = connectionPoints(in: items)
        let links = items.compactMap { $0 as? any ConnectionLink }
        ConnectionInteractionSupport.applyNormalization(
            to: &items,
            engine: engine,
            context: context,
            environment: environment,
            points: points,
            links: links
        )
        itemsBinding.wrappedValue = items
    }

    private func handleGlobalDrag(
        _ phase: CanvasGlobalDragPhase,
        context: RenderContext,
        controller: CanvasController
    ) {
        guard let itemsBinding = context.itemsBinding else { return }

        switch phase {
        case .began(let event):
            seedLiveLinkOrientation(points: connectionPoints, links: connectionLinks)
            globalDragTargetID = context.hitTargets.hitTest(event.rawLocation)?.id
        case .changed, .ended:
            if edgeDragController.isDragging {
                return
            }
            if case .changed = phase {
                let movedIDs: Set<UUID>
                if let targetID = globalDragTargetID {
                    movedIDs = [targetID]
                } else {
                    movedIDs = context.selectedItemIDs
                }
                applyLiveWireConstraints(
                    movedItemIDs: movedIDs,
                    itemsBinding: itemsBinding,
                    engine: engine
                )
            } else {
                var items = itemsBinding.wrappedValue
                ConnectionInteractionSupport.applyNormalization(
                    to: &items,
                    engine: engine,
                    context: context,
                    environment: environment,
                    points: connectionPoints(in: items),
                    links: items.compactMap { $0 as? any ConnectionLink }
                )
                itemsBinding.wrappedValue = items
                globalDragTargetID = nil
            }
        }
    }

    private var connectionPoints: [any ConnectionPoint] {
        connectionPoints(in: context.items)
    }

    private var connectionLinks: [any ConnectionLink] {
        context.connectionLinks
    }

    private var connectionPointPositionsByID: [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        positions.reserveCapacity(connectionPoints.count)
        for point in connectionPoints {
            positions[point.id] = point.position
        }
        return positions
    }

    private func symbolPinPoints(for components: [ComponentInstance]) -> [SymbolPinPoint] {
        var points: [SymbolPinPoint] = []
        for component in components {
            let symbol = component.symbolInstance
            guard let definition = symbol.definition else { continue }

            let rotation = symbol.rotation
            let transform = CGAffineTransform(rotationAngle: rotation)
            for pin in definition.pins {
                let rotated = pin.position.applying(transform)
                let position = CGPoint(
                    x: symbol.position.x + rotated.x,
                    y: symbol.position.y + rotated.y
                )
                points.append(
                    SymbolPinPoint(
                        symbolID: symbol.id,
                        pinID: pin.id,
                        position: position
                    )
                )
            }
        }
        return points
    }

    private func seedLiveLinkOrientation(points: [any ConnectionPoint], links: [any ConnectionLink])
    {
        guard !points.isEmpty, !links.isEmpty else {
            liveLinkOrientation = [:]
            return
        }

        let tolerance = 6.0 / max(context.magnification, 0.001)
        let positions = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        liveLinkOrientation = Dictionary(
            uniqueKeysWithValues: links.compactMap { link in
                guard let start = positions[link.startID],
                    let end = positions[link.endID]
                else { return nil }
                return (
                    link.id,
                    ConnectionInteractionSupport.classify(
                        start: start,
                        end: end,
                        tolerance: tolerance,
                        mode: .orthogonal
                    )
                )
            }
        )
    }

    private func symbolPinPointIDs(in points: [any ConnectionPoint]) -> [UUID: [UUID]] {
        var map: [UUID: [UUID]] = [:]
        for point in points {
            guard let pinPoint = point as? SymbolPinPoint else { continue }
            map[pinPoint.symbolID, default: []].append(pinPoint.id)
        }
        return map
    }

    private func applyLiveWireConstraints(
        movedItemIDs: Set<UUID>,
        itemsBinding: Binding<[any CanvasItem]>,
        engine: any ConnectionEngine
    ) {
        var items = itemsBinding.wrappedValue
        let points = connectionPoints
        let links = connectionLinks
        guard !points.isEmpty, !links.isEmpty else { return }

        let movedSymbolIDs = items.compactMap { item -> UUID? in
            guard let component = item as? ComponentInstance,
                movedItemIDs.contains(component.id)
            else { return nil }
            return component.symbolInstance.id
        }

        let symbolPinIDs = symbolPinPointIDs(in: points)
        let movedPinIDs = movedSymbolIDs.flatMap { symbolPinIDs[$0] ?? [] }
        guard !movedPinIDs.isEmpty else { return }

        let tolerance = 6.0 / max(context.magnification, 0.001)
        var positions = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        let linkOrientation = ConnectionInteractionSupport.buildOrientationMap(
            for: links,
            positions: positions,
            tolerance: tolerance,
            mode: .orthogonal,
            cache: &liveLinkOrientation
        )
        let adjacency = ConnectionInteractionSupport.linkAdjacency(for: links)
        let linkEndpoints = ConnectionInteractionSupport.linkEndpointMap(for: links)
        var fixedPointIDs = ConnectionInteractionSupport.fixedPointIDs(
            in: points,
            movablePoint: WireVertex.self
        )
        fixedPointIDs.subtract(movedPinIDs)

        ConnectionInteractionSupport.applyConstraints(
            movedIDs: movedPinIDs,
            positions: &positions,
            originalPositions: positions,
            adjacency: adjacency,
            orientations: linkOrientation,
            linkEndpoints: linkEndpoints,
            fixedPointIDs: fixedPointIDs,
            anchoredIDs: Set(movedPinIDs)
        )

        for index in items.indices {
            guard let vertex = items[index] as? WireVertex,
                let updated = positions[vertex.id],
                vertex.position != updated
            else { continue }
            var copy = vertex
            copy.position = updated
            items[index] = copy
        }

        let preferHorizontalFirst = (engine as? WireEngine)?.preferHorizontalFirst ?? true
        applySplitDiagonalNormalization(
            to: &items,
            preferHorizontalFirst: preferHorizontalFirst
        )

        itemsBinding.wrappedValue = items
    }

    private func connectionPoints(in items: [any CanvasItem]) -> [any ConnectionPoint] {
        let components = items.compactMap { $0 as? ComponentInstance }
        let wirePoints = items.compactMap { $0 as? WireVertex }
        return wirePoints + symbolPinPoints(for: components)
    }

    private func applySplitDiagonalNormalization(
        to items: inout [any CanvasItem],
        preferHorizontalFirst: Bool
    ) {
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let links = items.compactMap { $0 as? any ConnectionLink }
        guard !points.isEmpty, !links.isEmpty else { return }

        let epsilon = max(0.5 / max(context.magnification, 0.0001), 0.0001)
        var pointsByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        let pointsByObject = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
        let typedPointsByID: [UUID: WireVertex] = Dictionary(
            uniqueKeysWithValues: points.compactMap { point in
                guard let wirePoint = point as? WireVertex else { return nil }
                return (wirePoint.id, wirePoint)
            }
        )
        let originalLinksByID = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })
        let preferredIDs = Set(originalLinksByID.keys)

        var state = WireNormalizationState(
            pointsByID: pointsByID,
            pointsByObject: pointsByObject,
            typedPointsByID: typedPointsByID,
            links: links.map { WireSegment(id: $0.id, startID: $0.startID, endID: $0.endID) },
            addedPoints: [],
            removedPointIDs: [],
            removedLinkIDs: [],
            epsilon: epsilon,
            preferredIDs: preferredIDs
        )

        let rule = SplitDiagonalLinksRule(preferHorizontalFirst: preferHorizontalFirst)
        rule.apply(to: &state)

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
            && addedPointsOut.isEmpty
        {
            return
        }

        if !removedLinkIDs.isEmpty || !removedPointIDs.isEmpty {
            items.removeAll { item in
                removedLinkIDs.contains(item.id)
                    || removedPointIDs.contains(item.id)
            }
        }

        if !updatedLinks.isEmpty
            || !addedLinksOut.isEmpty
            || !addedPointsOut.isEmpty
        {
            var indexByID: [UUID: Int] = [:]
            indexByID.reserveCapacity(items.count)
            for (index, item) in items.enumerated() {
                indexByID[item.id] = index
            }

            func upsert(_ item: any CanvasItem) {
                if let index = indexByID[item.id] {
                    items[index] = item
                } else {
                    items.append(item)
                    indexByID[item.id] = items.count - 1
                }
            }

            for point in addedPointsOut {
                upsert(point)
            }
            for link in updatedLinks {
                upsert(link)
            }
            for link in addedLinksOut {
                upsert(link)
            }
        }
    }
}
