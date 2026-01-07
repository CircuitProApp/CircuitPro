import AppKit

final class WireEdgeDragInteraction: CanvasInteraction {
    private struct DragState {
        let edgeID: UUID
        let startID: UUID
        let endID: UUID
        let origin: CGPoint
        let startPosition: CGPoint
        let endPosition: CGPoint
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

        let anchorsByID = context.connectionAnchorPositionsByID
        let tolerance = baseTolerance / max(context.magnification, 0.001)

        for edge in context.connectionEdges {
            guard let start = anchorsByID[edge.startID],
                  let end = anchorsByID[edge.endID]
            else { continue }

            let isAxisAligned = abs(start.x - end.x) <= tolerance || abs(start.y - end.y) <= tolerance
            if isAxisAligned {
                let corner = CGPoint(x: end.x, y: start.y)
                if hitTest(point: point, start: start, end: corner, tolerance: tolerance)
                    || hitTest(point: point, start: corner, end: end, tolerance: tolerance) {
                    dragState = DragState(
                        edgeID: edge.id,
                        startID: edge.startID,
                        endID: edge.endID,
                        origin: point,
                        startPosition: start,
                        endPosition: end
                    )
                    return true
                }
            } else if hitTest(point: point, start: start, end: end, tolerance: tolerance) {
                dragState = DragState(
                    edgeID: edge.id,
                    startID: edge.startID,
                    endID: edge.endID,
                    origin: point,
                    startPosition: start,
                    endPosition: end
                )
                return true
            }
        }

        return false
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard let state = dragState,
              let itemsBinding = context.environment.items
        else { return }

        let rawDelta = CGVector(dx: point.x - state.origin.x, dy: point.y - state.origin.y)
        let snapped = context.snapProvider.snap(delta: rawDelta, context: context)
        let newStart = CGPoint(x: state.startPosition.x + snapped.dx, y: state.startPosition.y + snapped.dy)
        let newEnd = CGPoint(x: state.endPosition.x + snapped.dx, y: state.endPosition.y + snapped.dy)

        var items = itemsBinding.wrappedValue
        for index in items.indices {
            if items[index].id == state.startID, var vertex = items[index] as? WireVertex {
                vertex.position = newStart
                items[index] = vertex
            }
            if items[index].id == state.endID, var vertex = items[index] as? WireVertex {
                vertex.position = newEnd
                items[index] = vertex
            }
        }
        itemsBinding.wrappedValue = items
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard dragState != nil,
              let itemsBinding = context.environment.items,
              let engine = context.connectionEngine
        else {
            dragState = nil
            return
        }

        var items = itemsBinding.wrappedValue
        let anchors = items.compactMap { $0 as? any ConnectionAnchor }
        let edges = items.compactMap { $0 as? any ConnectionEdge }

        let input = ConnectionInput.edges(anchors: anchors, edges: edges)
        let normalizationContext = ConnectionNormalizationContext(
            magnification: context.magnification,
            snapPoint: { point in
                context.snapProvider.snap(point: point, context: context)
            }
        )
        let delta = engine.normalize(input, context: normalizationContext)

        if !delta.isEmpty {
            if !delta.removedEdgeIDs.isEmpty || !delta.removedAnchorIDs.isEmpty {
                items.removeAll { item in
                    delta.removedEdgeIDs.contains(item.id)
                        || delta.removedAnchorIDs.contains(item.id)
                }
            }

            if !delta.updatedAnchors.isEmpty
                || !delta.addedAnchors.isEmpty
                || !delta.updatedEdges.isEmpty
                || !delta.addedEdges.isEmpty {
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

                for anchor in delta.updatedAnchors {
                    upsert(anchor)
                }
                for anchor in delta.addedAnchors {
                    upsert(anchor)
                }
                for edge in delta.updatedEdges {
                    upsert(edge)
                }
                for edge in delta.addedEdges {
                    upsert(edge)
                }
            }

            itemsBinding.wrappedValue = items
        }

#if DEBUG
        if delta.isEmpty {
            print("Connection normalize: no changes")
        } else {
            print("Connection normalize:",
                  "anchors +\(delta.addedAnchors.count) ~\(delta.updatedAnchors.count) -\(delta.removedAnchorIDs.count),",
                  "edges +\(delta.addedEdges.count) ~\(delta.updatedEdges.count) -\(delta.removedEdgeIDs.count)")
        }
#endif

        dragState = nil
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
}
