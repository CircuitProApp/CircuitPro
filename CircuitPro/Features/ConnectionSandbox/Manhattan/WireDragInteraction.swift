import AppKit

final class WireDragInteraction: CanvasInteraction {
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

    private var dragState: DragState?
    private let baseTolerance: CGFloat = 6

    func mouseDown(
        with event: NSEvent,
        at point: CGPoint,
        context: RenderContext,
        controller: CanvasController
    ) -> Bool {
        dragState = nil

        let pointsByID = context.connectionPointPositionsByID
        let tolerance = baseTolerance / max(context.magnification, 0.001)

        let links = context.connectionLinks
        let linkAxis = linkAxisMap(for: links, positions: pointsByID, tolerance: tolerance)
        let adjacency = linkAdjacency(for: links)
        let linkEndpoints = linkEndpointMap(for: links)
        let fixedPointIDs = fixedPoints(in: context.connectionPoints)

        for link in links {
            guard let start = pointsByID[link.startID],
                  let end = pointsByID[link.endID]
            else { continue }

            let isAxisAligned = abs(start.x - end.x) <= tolerance || abs(start.y - end.y) <= tolerance
            if isAxisAligned {
                let corner = CGPoint(x: end.x, y: start.y)
                if hitTest(point: point, start: start, end: corner, tolerance: tolerance)
                    || hitTest(point: point, start: corner, end: end, tolerance: tolerance) {
                    dragState = DragState(
                        edgeID: link.id,
                        startID: link.startID,
                        endID: link.endID,
                        origin: point,
                        startPosition: start,
                        endPosition: end,
                        originalPositions: pointsByID,
                        linkAxis: linkAxis,
                        adjacency: adjacency,
                        linkEndpoints: linkEndpoints,
                        fixedPointIDs: fixedPointIDs
                    )
                    return true
                }
            } else if hitTest(point: point, start: start, end: end, tolerance: tolerance) {
                dragState = DragState(
                    edgeID: link.id,
                    startID: link.startID,
                    endID: link.endID,
                    origin: point,
                    startPosition: start,
                    endPosition: end,
                    originalPositions: pointsByID,
                    linkAxis: linkAxis,
                    adjacency: adjacency,
                    linkEndpoints: linkEndpoints,
                    fixedPointIDs: fixedPointIDs
                )
                return true
            }
        }

        return false
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard var state = dragState,
              let itemsBinding = context.itemsBinding
        else { return }

        let rawDelta = CGVector(dx: point.x - state.origin.x, dy: point.y - state.origin.y)
        let snapped = context.snapProvider.snap(delta: rawDelta, context: context)
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

        let newStart = CGPoint(x: state.startPosition.x + snapped.dx, y: state.startPosition.y + snapped.dy)
        let newEnd = CGPoint(x: state.endPosition.x + snapped.dx, y: state.endPosition.y + snapped.dy)
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
               vertex.position != updated {
                var copy = vertex
                copy.position = updated
                items[index] = copy
            }
        }
        itemsBinding.wrappedValue = items
        dragState = state
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard dragState != nil,
              let itemsBinding = context.itemsBinding,
              let engine = context.connectionEngine
        else {
            dragState = nil
            return
        }

        var items = itemsBinding.wrappedValue
        applyNormalization(to: &items, context: context, engine: engine)
        itemsBinding.wrappedValue = items

        dragState = nil
    }

    private func applyNormalization(
        to items: inout [any CanvasItem],
        context: RenderContext,
        engine: any ConnectionEngine
    ) {
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let links = items.compactMap { $0 as? any ConnectionLink }
        let normalizationContext = ConnectionNormalizationContext(
            magnification: context.magnification,
            snapPoint: { point in
                context.snapProvider.snap(point: point, context: context)
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
            || !delta.addedLinks.isEmpty {
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

#if DEBUG
        let pointCount = items.reduce(0) { $0 + ((($1 as? any ConnectionPoint) != nil) ? 1 : 0) }
        let wirePointCount = items.reduce(0) { $0 + ((($1 as? WireVertex) != nil) ? 1 : 0) }
        let pinPointCount = items.reduce(0) { $0 + ((($1 as? SymbolPinPoint) != nil) ? 1 : 0) }
        let linkCount = items.reduce(0) { $0 + ((($1 as? any ConnectionLink) != nil) ? 1 : 0) }
        print(
            "Connection normalize:",
            "points \(pointCount),",
            "wirePoints \(wirePointCount),",
            "pinPoints \(pinPointCount),",
            "links \(linkCount)"
        )
#endif
    }

    private func hitTest(
        point: CGPoint,
        start: CGPoint,
        end: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        let padding = tolerance
        let minX = min(start.x, end.x) - padding
        let maxX = max(start.x, end.x) + padding
        let minY = min(start.y, end.y) - padding
        let maxY = max(start.y, end.y) + padding

        guard point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY else {
            return false
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let epsilon: CGFloat = 1e-6
        if abs(dx) < epsilon { return abs(point.x - start.x) < padding }
        if abs(dy) < epsilon { return abs(point.y - start.y) < padding }

        let distance = abs(
            dy * point.x - dx * point.y + end.y * start.x - end.x * start.y
        ) / hypot(dx, dy)
        return distance < padding
    }

    private enum Axis {
        case horizontal
        case vertical
        case diagonal
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
           var segment = items[index] as? WireSegment {
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
            let newAxis: Axis = (axis == .horizontal) ? .vertical : (axis == .vertical ? .horizontal : .diagonal)
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
                || (link.startID == b && link.endID == a) {
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
        fixedPointIDs: Set<UUID>
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
                    positions[currentID] = align(current: currentPos, fixed: otherOrig, axis: axis)
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
}
