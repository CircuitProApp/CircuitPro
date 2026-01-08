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

        let pointsByID = context.connectionPointPositionsByID
        let tolerance = baseTolerance / max(context.magnification, 0.001)

        for link in context.connectionLinks {
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
                        endPosition: end
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
                    endPosition: end
                )
                return true
            }
        }

        return false
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard let state = dragState,
              let itemsBinding = context.environment.items,
              let engine = context.connectionEngine
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
        applyNormalization(to: &items, context: context, engine: engine)
        itemsBinding.wrappedValue = items
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
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
