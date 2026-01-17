import AppKit
import SwiftUI

struct WireView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    @CKState private var dragState: DragState?
    @CKState private var liveLinkAxis: [UUID: Axis] = [:]
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
            beginDrag(linkID: linkID)
        case .changed(let delta):
            updateDrag(delta: delta)
        case .ended:
            endDrag()
        }
    }

    private func beginDrag(linkID: UUID) {
        dragState = nil

        let pointsByID = connectionPointPositionsByID
        let tolerance = baseTolerance / max(context.magnification, 0.001)

        let links = connectionLinks
        guard let link = links.first(where: { $0.id == linkID }),
            let start = pointsByID[link.startID],
            let end = pointsByID[link.endID]
        else { return }

        let linkAxis = linkAxisMap(for: links, positions: pointsByID, tolerance: tolerance)
        let adjacency = linkAdjacency(for: links)
        let linkEndpoints = linkEndpointMap(for: links)
        let fixedPointIDs = fixedPoints(in: connectionPoints)

        dragState = DragState(
            edgeID: linkID,
            startID: link.startID,
            endID: link.endID,
            origin: environment.processedMouseLocation ?? context.mouseLocation ?? .zero,
            startPosition: start,
            endPosition: end,
            originalPositions: pointsByID,
            linkAxis: linkAxis,
            adjacency: adjacency,
            linkEndpoints: linkEndpoints,
            fixedPointIDs: fixedPointIDs
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
            otherID: state.endID,
            axis: state.linkAxis[state.edgeID],
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
            otherID: state.startID,
            axis: state.linkAxis[state.edgeID],
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
        applyOrthogonalConstraints(
            movedIDs: [state.startID, state.endID].filter { !state.fixedPointIDs.contains($0) },
            positions: &newPositions,
            originalPositions: state.originalPositions,
            adjacency: state.adjacency,
            linkAxis: state.linkAxis,
            linkEndpoints: state.linkEndpoints,
            fixedPointIDs: state.fixedPointIDs
        )

        for index in items.indices {
            if items[index].id == state.startID, var vertex = items[index] as? WireVertex {
                vertex.position = newPositions[state.startID] ?? newStart
                items[index] = vertex
            }
            if items[index].id == state.endID, var vertex = items[index] as? WireVertex {
                vertex.position = newPositions[state.endID] ?? newEnd
                items[index] = vertex
            }
            if let vertex = items[index] as? WireVertex,
                let updated = newPositions[vertex.id],
                vertex.position != updated
            {
                var copy = vertex
                copy.position = updated
                items[index] = copy
            }
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
        applyNormalization(
            to: &items, engine: engine, points: connectionPoints, links: connectionLinks)
        itemsBinding.wrappedValue = items
        dragState = nil
    }

    private func applyNormalization(
        to items: inout [any CanvasItem],
        engine: any ConnectionEngine,
        points: [any ConnectionPoint],
        links: [any ConnectionLink]
    ) {
        let normalizationContext = ConnectionNormalizationContext(
            magnification: context.magnification,
            snapPoint: { point in
                context.snapProvider.snap(point: point, context: context, environment: environment)
            }
        )
        let delta = engine.normalize(points: points, links: links, context: normalizationContext)

        if delta.isEmpty {
            return
        }

        if !delta.removedLinkIDs.isEmpty || !delta.removedPointIDs.isEmpty {
            items.removeAll { item in
                delta.removedLinkIDs.contains(item.id)
                    || delta.removedPointIDs.contains(item.id)
            }
        }

        if !delta.updatedPoints.isEmpty
            || !delta.addedPoints.isEmpty
            || !delta.updatedLinks.isEmpty
            || !delta.addedLinks.isEmpty
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

            for point in delta.updatedPoints {
                upsert(point)
            }
            for point in delta.addedPoints {
                upsert(point)
            }
            for link in delta.updatedLinks {
                upsert(link)
            }
            for link in delta.addedLinks {
                upsert(link)
            }
        }
    }

    private func handleGlobalDrag(
        _ phase: CanvasGlobalDragPhase,
        context: RenderContext,
        controller: CanvasController
    ) {
        guard let itemsBinding = context.itemsBinding else { return }

        switch phase {
        case .began(let event):
            seedLiveLinkAxis(points: connectionPoints, links: connectionLinks)
            globalDragTargetID = context.hitTargets.hitTest(event.rawLocation)?.id
        case .changed, .ended:
            if dragState != nil {
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
                applyNormalization(
                    to: &items,
                    engine: engine,
                    points: connectionPoints,
                    links: connectionLinks
                )
                itemsBinding.wrappedValue = items
                globalDragTargetID = nil
            }
        }
    }

    private var connectionPoints: [any ConnectionPoint] {
        let components = context.items.compactMap { $0 as? ComponentInstance }
        let wirePoints = context.items.compactMap { $0 as? WireVertex }
        return wirePoints + symbolPinPoints(for: components)
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

    private enum Axis {
        case horizontal
        case vertical
        case diagonal
    }

    private struct DragState {
        let edgeID: UUID
        var startID: UUID
        var endID: UUID
        let origin: CGPoint
        var startPosition: CGPoint
        var endPosition: CGPoint
        var originalPositions: [UUID: CGPoint]
        var linkAxis: [UUID: Axis]
        var adjacency: [UUID: [UUID]]
        var linkEndpoints: [UUID: (UUID, UUID)]
        var fixedPointIDs: Set<UUID>
    }

    private func detachIfNeeded(
        endpointID: UUID,
        otherID: UUID,
        axis: Axis?,
        snapped: CGVector,
        tolerance: CGFloat,
        state: inout DragState,
        items: inout [any CanvasItem],
        replacingStart: Bool
    ) -> Bool {
        guard state.fixedPointIDs.contains(endpointID),
            let axis
        else { return false }

        let isOffAxis: Bool
        switch axis {
        case .horizontal:
            isOffAxis = abs(snapped.dy) > tolerance
        case .vertical:
            isOffAxis = abs(snapped.dx) > tolerance
        case .diagonal:
            isOffAxis = true
        }
        guard isOffAxis else { return false }

        guard let endpointPosition = state.originalPositions[endpointID] else { return false }
        let newVertex = WireVertex(position: endpointPosition)
        items.append(newVertex)
        state.originalPositions[newVertex.id] = endpointPosition

        if replacingStart {
            state.startID = newVertex.id
            state.startPosition = endpointPosition
        } else {
            state.endID = newVertex.id
            state.endPosition = endpointPosition
        }

        if let index = items.firstIndex(where: { $0.id == state.edgeID }),
            var segment = items[index] as? WireSegment
        {
            if segment.startID == endpointID {
                segment.startID = newVertex.id
            } else if segment.endID == endpointID {
                segment.endID = newVertex.id
            }
            items[index] = segment
        }

        if !hasLink(between: endpointID, and: newVertex.id, items: items) {
            let link = WireSegment(startID: endpointID, endID: newVertex.id)
            items.append(link)
            let newAxis: Axis =
                (axis == .horizontal) ? .vertical : (axis == .vertical ? .horizontal : .diagonal)
            state.linkAxis[link.id] = newAxis
        }

        let links = items.compactMap { $0 as? any ConnectionLink }
        state.adjacency = linkAdjacency(for: links)
        state.linkEndpoints = linkEndpointMap(for: links)
        state.linkAxis[state.edgeID] = axis

        return true
    }

    private func hasLink(
        between a: UUID,
        and b: UUID,
        items: [any CanvasItem]
    ) -> Bool {
        let links = items.compactMap { $0 as? any ConnectionLink }
        for link in links {
            if (link.startID == a && link.endID == b)
                || (link.startID == b && link.endID == a)
            {
                return true
            }
        }
        return false
    }

    private func linkAxisMap(
        for links: [any ConnectionLink],
        positions: [UUID: CGPoint],
        tolerance: CGFloat
    ) -> [UUID: Axis] {
        var map: [UUID: Axis] = [:]
        map.reserveCapacity(links.count)
        var currentIDs = Set<UUID>()
        currentIDs.reserveCapacity(links.count)

        for link in links {
            currentIDs.insert(link.id)
            if let axis = liveLinkAxis[link.id] {
                map[link.id] = axis
                continue
            }

            guard let start = positions[link.startID],
                let end = positions[link.endID]
            else { continue }
            let dx = abs(start.x - end.x)
            let dy = abs(start.y - end.y)
            let axis: Axis
            if dx <= tolerance {
                axis = .vertical
            } else if dy <= tolerance {
                axis = .horizontal
            } else {
                axis = .diagonal
            }
            liveLinkAxis[link.id] = axis
            map[link.id] = axis
        }

        liveLinkAxis = liveLinkAxis.filter { currentIDs.contains($0.key) }
        return map
    }

    private func linkAdjacency(for links: [any ConnectionLink]) -> [UUID: [UUID]] {
        var adjacency: [UUID: [UUID]] = [:]
        for link in links {
            adjacency[link.startID, default: []].append(link.id)
            adjacency[link.endID, default: []].append(link.id)
        }
        return adjacency
    }

    private func linkEndpointMap(for links: [any ConnectionLink]) -> [UUID: (UUID, UUID)] {
        var map: [UUID: (UUID, UUID)] = [:]
        map.reserveCapacity(links.count)
        for link in links {
            map[link.id] = (link.startID, link.endID)
        }
        return map
    }

    private func fixedPoints(in points: [any ConnectionPoint]) -> Set<UUID> {
        var fixed = Set<UUID>()
        fixed.reserveCapacity(points.count)
        for point in points where !(point is WireVertex) {
            fixed.insert(point.id)
        }
        return fixed
    }

    private func applyOrthogonalConstraints(
        movedIDs: [UUID],
        positions: inout [UUID: CGPoint],
        originalPositions: [UUID: CGPoint],
        adjacency: [UUID: [UUID]],
        linkAxis: [UUID: Axis],
        linkEndpoints: [UUID: (UUID, UUID)],
        fixedPointIDs: Set<UUID>,
        anchoredIDs: Set<UUID> = []
    ) {
        var queue = movedIDs
        var queued = Set(movedIDs)

        func isFixed(_ id: UUID) -> Bool {
            fixedPointIDs.contains(id)
        }

        while let currentID = queue.first {
            queue.removeFirst()
            queued.remove(currentID)

            guard let currentPos = positions[currentID],
                let currentOrig = originalPositions[currentID]
            else { continue }

            for linkID in adjacency[currentID] ?? [] {
                guard let axis = linkAxis[linkID],
                    let endpoints = linkEndpoints[linkID]
                else { continue }

                let (aID, bID) = endpoints
                let otherID = (aID == currentID) ? bID : aID
                guard otherID != currentID else { continue }

                guard let otherOrig = originalPositions[otherID] else { continue }
                var otherPos = positions[otherID] ?? otherOrig

                switch axis {
                case .horizontal:
                    otherPos.y = currentPos.y
                case .vertical:
                    otherPos.x = currentPos.x
                case .diagonal:
                    continue
                }

                if isFixed(otherID) {
                    if !anchoredIDs.contains(currentID) {
                        positions[currentID] = align(
                            current: currentPos, fixed: otherOrig, axis: axis)
                    }
                } else if positions[otherID] != otherPos {
                    positions[otherID] = otherPos
                    if !queued.contains(otherID) {
                        queue.append(otherID)
                        queued.insert(otherID)
                    }
                }
            }
        }
    }

    private func align(current: CGPoint, fixed: CGPoint, axis: Axis) -> CGPoint {
        switch axis {
        case .horizontal:
            return CGPoint(x: current.x, y: fixed.y)
        case .vertical:
            return CGPoint(x: fixed.x, y: current.y)
        case .diagonal:
            return current
        }
    }

    private func seedLiveLinkAxis(points: [any ConnectionPoint], links: [any ConnectionLink]) {
        guard !points.isEmpty, !links.isEmpty else {
            liveLinkAxis = [:]
            return
        }

        let tolerance = 6.0 / max(context.magnification, 0.001)
        let positions = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        var map: [UUID: Axis] = [:]
        map.reserveCapacity(links.count)

        for link in links {
            guard let start = positions[link.startID],
                let end = positions[link.endID]
            else { continue }
            let dx = abs(start.x - end.x)
            let dy = abs(start.y - end.y)
            if dx <= tolerance {
                map[link.id] = .vertical
            } else if dy <= tolerance {
                map[link.id] = .horizontal
            } else {
                map[link.id] = .diagonal
            }
        }

        liveLinkAxis = map
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
        let linkAxis = linkAxisMap(for: links, positions: positions, tolerance: tolerance)
        let adjacency = linkAdjacency(for: links)
        let linkEndpoints = linkEndpointMap(for: links)
        var fixedPointIDs = fixedPoints(in: points)
        fixedPointIDs.subtract(movedPinIDs)

        applyOrthogonalConstraints(
            movedIDs: movedPinIDs,
            positions: &positions,
            originalPositions: positions,
            adjacency: adjacency,
            linkAxis: linkAxis,
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
