import AppKit
import SwiftUI

final class ManhattanWireTool: CanvasTool {
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
        guard let itemsBinding = context.renderContext.environment.items else {
            return .noResult
        }

        var items = itemsBinding.wrappedValue
        let magnification = max(context.renderContext.magnification, 0.0001)
        let snapPoint = context.renderContext.snapProvider.snap(
            point: location,
            context: context.renderContext
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
                    items.append(WireSegment(startID: state.startID, endID: cornerID))
                }
                if cornerID != endID {
                    items.append(WireSegment(startID: cornerID, endID: endID))
                }
            } else if state.startID != endID {
                items.append(WireSegment(startID: state.startID, endID: endID))
            }

            applyNormalization(to: &items, context: context.renderContext)

            if context.clickCount >= 2 {
                self.state = nil
            } else {
                let isStraight = abs(state.startPoint.x - endPoint.x) <= tolerance
                    || abs(state.startPoint.y - endPoint.y) <= tolerance
                let nextDirection = isStraight ? state.direction.toggled() : state.direction
                self.state = DrawingState(startID: endID, startPoint: endPoint, direction: nextDirection)
            }
        } else {
            self.state = DrawingState(startID: endID, startPoint: endPoint, direction: .horizontal)
        }

        itemsBinding.wrappedValue = items
        return .noResult
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        guard let state else { return [] }

        let snapped = context.snapProvider.snap(point: mouse, context: context)
        let corner = cornerPoint(from: state.startPoint, to: snapped, direction: state.direction)

        let path = CGMutablePath()
        path.move(to: state.startPoint)
        path.addLine(to: corner)
        path.addLine(to: snapped)

        return [
            .stroke(
                path: path,
                color: NSColor.systemBlue.cgColor,
                lineWidth: 1.0,
                lineDash: [4, 4]
            )
        ]
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

    private func applyNormalization(
        to items: inout [any CanvasItem],
        context: RenderContext
    ) {
        guard let engine = context.connectionEngine else { return }
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let links = items.compactMap { $0 as? any ConnectionLink }
        let normalizationContext = ConnectionNormalizationContext(
            magnification: context.magnification,
            snapPoint: { point in
                context.snapProvider.snap(point: point, context: context)
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
