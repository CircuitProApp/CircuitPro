import AppKit
import SwiftUI

final class WireTool: CanvasTool {
    private let engine: (any ConnectionEngine)?

    init(engine: (any ConnectionEngine)? = nil) {
        self.engine = engine
        super.init()
    }
    override var symbolName: String { CircuitProSymbols.Schematic.wire }
    override var label: String { "Wire" }

    private enum DrawingDirection {
        case horizontal
        case vertical

        func toggled() -> DrawingDirection {
            self == .horizontal ? .vertical : .horizontal
        }
    }

    private struct DrawingState {
        let startID: UUID
        let startPoint: CGPoint
        let direction: DrawingDirection
    }

    private var state: DrawingState?

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        guard let itemsBinding = context.renderContext.itemsBinding else {
            return .noResult
        }

        var items = itemsBinding.wrappedValue
        let magnification = max(context.renderContext.magnification, 0.0001)
        let snapPoint = context.renderContext.snapProvider.snap(
            point: location,
            context: context.renderContext,
            environment: context.environment
        )
        let tolerance = 6.0 / magnification

        let (endID, endPoint) = resolvePoint(
            near: location,
            snapped: snapPoint,
            items: &items,
            tolerance: tolerance
        )

        if let state {
            let corner = cornerPoint(from: state.startPoint, to: endPoint, direction: state.direction)
            let cornerID = resolveCorner(
                corner,
                items: &items,
                tolerance: tolerance
            )

            if let cornerID, corner != state.startPoint && corner != endPoint {
                if state.startID != cornerID {
                    appendLinkIfMissing(
                        startID: state.startID,
                        endID: cornerID,
                        items: &items,
                        tolerance: tolerance,
                        allowCovered: true
                    )
                }
                if cornerID != endID {
                    appendLinkIfMissing(startID: cornerID, endID: endID, items: &items, tolerance: tolerance)
                }
            } else if state.startID != endID {
            appendLinkIfMissing(startID: state.startID, endID: endID, items: &items, tolerance: tolerance)
        }

            applyNormalization(
                to: &items,
                context: context.renderContext,
                environment: context.environment
            )

            let resolved = ensurePointExists(
                id: endID,
                position: endPoint,
                items: &items,
                tolerance: tolerance
            )

            if context.clickCount >= 2 {
                self.state = nil
            } else {
                let isStraight = abs(state.startPoint.x - resolved.position.x) <= tolerance
                    || abs(state.startPoint.y - resolved.position.y) <= tolerance
                let nextDirection = isStraight ? state.direction.toggled() : state.direction
                self.state = DrawingState(
                    startID: resolved.id,
                    startPoint: resolved.position,
                    direction: nextDirection
                )
            }
        } else {
            self.state = DrawingState(startID: endID, startPoint: endPoint, direction: .horizontal)
        }

        itemsBinding.wrappedValue = items
        return .noResult
    }

    override func preview(
        mouse: CGPoint,
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) -> CKGroup {
        guard let state else { return CKGroup() }

        let snapped = context.snapProvider.snap(
            point: mouse,
            context: context,
            environment: environment
        )
        let corner = cornerPoint(from: state.startPoint, to: snapped, direction: state.direction)

        let path = CGMutablePath()
        path.move(to: state.startPoint)
        path.addLine(to: corner)
        path.addLine(to: snapped)

        return CKGroup {
            CKPath(path: path)
                .stroke(NSColor.systemBlue.cgColor, width: 1.0)
                .lineDash([4, 4])
        }
    }

    override func handleEscape() -> Bool {
        if state != nil {
            state = nil
            return true
        }
        return false
    }

    private func resolvePoint(
        near location: CGPoint,
        snapped: CGPoint,
        items: inout [any CanvasItem],
        tolerance: CGFloat
    ) -> (UUID, CGPoint) {
        let points = items.compactMap { $0 as? any ConnectionPoint }
        if let existing = nearestPoint(to: location, in: points, tolerance: tolerance) {
            return (existing.id, existing.position)
        }

        let pointsByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        let links = items.compactMap { $0 as? any ConnectionLink }
        if let hit = nearestLinkHit(to: location, links: links, pointsByID: pointsByID, tolerance: tolerance) {
            let snappedHit = snapPoint(on: hit, snapped: snapped, tolerance: tolerance)
            let startDist = hypot(snappedHit.x - hit.start.x, snappedHit.y - hit.start.y)
            if startDist <= tolerance {
                return (hit.startID, hit.start)
            }
            let endDist = hypot(snappedHit.x - hit.end.x, snappedHit.y - hit.end.y)
            if endDist <= tolerance {
                return (hit.endID, hit.end)
            }
            if let existing = nearestPoint(to: snappedHit, in: points, tolerance: tolerance) {
                return (existing.id, existing.position)
            }

            let vertex = WireVertex(position: snappedHit)
            items.append(vertex)
            splitLink(hit, newPointID: vertex.id, items: &items)
            return (vertex.id, vertex.position)
        }

        let vertex = WireVertex(position: snapped)
        items.append(vertex)
        return (vertex.id, vertex.position)
    }

    private func resolveCorner(
        _ corner: CGPoint,
        items: inout [any CanvasItem],
        tolerance: CGFloat
    ) -> UUID? {
        let points = items.compactMap { $0 as? any ConnectionPoint }
        if let existing = nearestPoint(to: corner, in: points, tolerance: tolerance) {
            return existing.id
        }

        let vertex = WireVertex(position: corner)
        items.append(vertex)
        return vertex.id
    }

    private func nearestPoint(
        to location: CGPoint,
        in points: [any ConnectionPoint],
        tolerance: CGFloat
    ) -> (any ConnectionPoint)? {
        var best: (point: any ConnectionPoint, distance: CGFloat)?
        for point in points {
            let distance = hypot(point.position.x - location.x, point.position.y - location.y)
            if distance <= tolerance {
                if let current = best {
                    if distance < current.distance { best = (point, distance) }
                } else {
                    best = (point, distance)
                }
            }
        }
        return best?.point
    }

    private func cornerPoint(
        from start: CGPoint,
        to end: CGPoint,
        direction: DrawingDirection
    ) -> CGPoint {
        switch direction {
        case .horizontal:
            return CGPoint(x: end.x, y: start.y)
        case .vertical:
            return CGPoint(x: start.x, y: end.y)
        }
    }

    private struct LinkHit {
        let id: UUID
        let startID: UUID
        let endID: UUID
        let start: CGPoint
        let end: CGPoint
        let projection: CGPoint
        let distance: CGFloat
    }

    private func nearestLinkHit(
        to location: CGPoint,
        links: [any ConnectionLink],
        pointsByID: [UUID: CGPoint],
        tolerance: CGFloat
    ) -> LinkHit? {
        var best: LinkHit?
        for link in links {
            guard let start = pointsByID[link.startID],
                  let end = pointsByID[link.endID]
            else { continue }

            let projection = closestPoint(on: start, to: end, target: location)
            let distance = hypot(location.x - projection.x, location.y - projection.y)
            if distance > tolerance { continue }

            if let current = best {
                if distance < current.distance {
                    best = LinkHit(
                        id: link.id,
                        startID: link.startID,
                        endID: link.endID,
                        start: start,
                        end: end,
                        projection: projection,
                        distance: distance
                    )
                }
            } else {
                best = LinkHit(
                    id: link.id,
                    startID: link.startID,
                    endID: link.endID,
                    start: start,
                    end: end,
                    projection: projection,
                    distance: distance
                )
            }
        }
        return best
    }

    private func closestPoint(on start: CGPoint, to end: CGPoint, target: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len2 = dx * dx + dy * dy
        if len2 <= .ulpOfOne {
            return start
        }
        let t = ((target.x - start.x) * dx + (target.y - start.y) * dy) / len2
        let clamped = min(max(t, 0), 1)
        return CGPoint(x: start.x + clamped * dx, y: start.y + clamped * dy)
    }

    private func snapPoint(on hit: LinkHit, snapped: CGPoint, tolerance: CGFloat) -> CGPoint {
        let dx = hit.end.x - hit.start.x
        let dy = hit.end.y - hit.start.y
        if abs(dx) <= tolerance {
            let minY = min(hit.start.y, hit.end.y)
            let maxY = max(hit.start.y, hit.end.y)
            let y = min(max(snapped.y, minY), maxY)
            return CGPoint(x: hit.start.x, y: y)
        }
        if abs(dy) <= tolerance {
            let minX = min(hit.start.x, hit.end.x)
            let maxX = max(hit.start.x, hit.end.x)
            let x = min(max(snapped.x, minX), maxX)
            return CGPoint(x: x, y: hit.start.y)
        }
        return hit.projection
    }

    private func splitLink(
        _ hit: LinkHit,
        newPointID: UUID,
        items: inout [any CanvasItem]
    ) {
        items.removeAll { $0.id == hit.id }
        appendLinkIfMissing(
            startID: hit.startID,
            endID: newPointID,
            existingID: hit.id,
            items: &items,
            tolerance: 0.5
        )
        appendLinkIfMissing(startID: newPointID, endID: hit.endID, items: &items, tolerance: 0.5)
    }

    private func appendLinkIfMissing(
        startID: UUID,
        endID: UUID,
        existingID: UUID? = nil,
        items: inout [any CanvasItem],
        tolerance: CGFloat,
        allowCovered: Bool = false
    ) {
        if hasLink(between: startID, and: endID, items: items) {
            return
        }
        if !allowCovered,
           segmentCoveredByExistingLink(startID: startID, endID: endID, items: items, tolerance: tolerance) {
            return
        }
        if let existingID {
            items.append(WireSegment(id: existingID, startID: startID, endID: endID))
        } else {
            items.append(WireSegment(startID: startID, endID: endID))
        }
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

    private func segmentCoveredByExistingLink(
        startID: UUID,
        endID: UUID,
        items: [any CanvasItem],
        tolerance: CGFloat
    ) -> Bool {
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let pointsByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        guard let start = pointsByID[startID], let end = pointsByID[endID] else { return false }

        let links = items.compactMap { $0 as? any ConnectionLink }
        for link in links {
            guard let lStart = pointsByID[link.startID],
                  let lEnd = pointsByID[link.endID]
            else { continue }
            if isPoint(start, onSegmentBetween: lStart, p2: lEnd, tol: tolerance),
               isPoint(end, onSegmentBetween: lStart, p2: lEnd, tol: tolerance) {
                return true
            }
        }
        return false
    }

    private func ensurePointExists(
        id: UUID,
        position: CGPoint,
        items: inout [any CanvasItem],
        tolerance: CGFloat
    ) -> (id: UUID, position: CGPoint) {
        if let existing = items.first(where: { $0.id == id }) as? any ConnectionPoint {
            return (existing.id, existing.position)
        }

        let points = items.compactMap { $0 as? any ConnectionPoint }
        if let nearby = nearestPoint(to: position, in: points, tolerance: tolerance) {
            return (nearby.id, nearby.position)
        }

        let vertex = WireVertex(position: position)
        items.append(vertex)
        return (vertex.id, vertex.position)
    }

    private func applyNormalization(
        to items: inout [any CanvasItem],
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) {
        guard let engine else { return }
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let links = items.compactMap { $0 as? any ConnectionLink }
        let normalizationContext = ConnectionNormalizationContext(
            magnification: context.magnification,
            snapPoint: { point in
                context.snapProvider.snap(point: point, context: context, environment: environment)
            }
        )
        let delta = engine.normalize(points: points, links: links, context: normalizationContext)
        if delta.isEmpty { return }

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

            for point in delta.updatedPoints { upsert(point) }
            for point in delta.addedPoints { upsert(point) }
            for link in delta.updatedLinks { upsert(link) }
            for link in delta.addedLinks { upsert(link) }
        }
    }
}
