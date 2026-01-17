//
//  TraceTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import AppKit
import SwiftUI

final class TraceTool: CanvasTool {
    override var symbolName: String { "scribble.variable" }
    override var label: String { "Trace" }

    // This property would be updated by a UI control (e.g., a text field in a toolbar).
    // It is initialized with the application's default value.
    var currentTraceWidthInPoints: CGFloat = CircuitPro.Constants.defaultTraceWidthMM * CircuitPro.Constants.pointsPerMillimeter

    private struct DrawingState {
        let startID: UUID
        let startPoint: CGPoint
    }
    private var state: DrawingState?
    private let traceEngine: TraceEngine

    init(traceEngine: TraceEngine = TraceEngine()) {
        self.traceEngine = traceEngine
        super.init()
    }

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        guard let itemsBinding = context.renderContext.itemsBinding else {
            return .noResult
        }
        guard let activeLayerId = context.activeLayerId else {
            print("TraceTool Error: No active layer selected.")
            return .noResult
        }

        let traceWidth = currentTraceWidthInPoints
        let magnification = max(context.renderContext.magnification, 0.0001)
        let snapped = context.renderContext.snapProvider.snap(
            point: location,
            context: context.renderContext,
            environment: context.environment
        )
        let tolerance = 6.0 / magnification
        var items = itemsBinding.wrappedValue

        let (endID, endPoint) = resolvePoint(
            near: location,
            snapped: snapped,
            items: &items,
            tolerance: tolerance
        )

        if let state {
            let pathPoints = traceEngine.route(from: state.startPoint, to: endPoint)
            let ids = ensurePointsExist(
                for: pathPoints,
                items: &items,
                tolerance: tolerance
            )
            appendLinks(
                for: ids,
                width: traceWidth,
                layerId: activeLayerId,
                items: &items
            )

            applyNormalization(
                to: &items,
                context: context.renderContext,
                environment: context.environment
            )

            if context.clickCount >= 2 {
                self.state = nil
            } else if let lastID = ids.last,
                      let lastPoint = position(for: lastID, items: items) {
                self.state = DrawingState(startID: lastID, startPoint: lastPoint)
            } else {
                self.state = DrawingState(startID: endID, startPoint: endPoint)
            }
        } else {
            self.state = DrawingState(startID: endID, startPoint: endPoint)
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

        let color = context.layers.first(where: { $0.id == context.activeLayerId })?.color ?? NSColor.systemBlue.cgColor

        let snapped = context.snapProvider.snap(
            point: mouse,
            context: context,
            environment: environment
        )
        let pathPoints = traceEngine.route(from: state.startPoint, to: snapped)

        let path = CGMutablePath()
        guard let firstPoint = pathPoints.first else { return CKGroup() }
        path.move(to: firstPoint)
        for i in 1..<pathPoints.count {
            path.addLine(to: pathPoints[i])
        }

        return CKGroup {
            CKPath(path: path)
                .stroke(color, width: self.currentTraceWidthInPoints)
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
        let points = items.compactMap { $0 as? TraceVertex }
        if let existing = nearestPoint(to: location, in: points, tolerance: tolerance) {
            return (existing.id, existing.position)
        }

        let vertex = TraceVertex(position: snapped)
        items.append(vertex)
        return (vertex.id, vertex.position)
    }

    private func nearestPoint(
        to location: CGPoint,
        in points: [TraceVertex],
        tolerance: CGFloat
    ) -> TraceVertex? {
        var best: (point: TraceVertex, distance: CGFloat)?
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

    private func ensurePointsExist(
        for pathPoints: [CGPoint],
        items: inout [any CanvasItem],
        tolerance: CGFloat
    ) -> [UUID] {
        var ids: [UUID] = []
        ids.reserveCapacity(pathPoints.count)

        for point in pathPoints {
            if let existing = nearestPoint(to: point, in: items.compactMap { $0 as? TraceVertex }, tolerance: tolerance) {
                ids.append(existing.id)
                continue
            }
            let vertex = TraceVertex(position: point)
            items.append(vertex)
            ids.append(vertex.id)
        }

        return ids
    }

    private func appendLinks(
        for ids: [UUID],
        width: CGFloat,
        layerId: UUID,
        items: inout [any CanvasItem]
    ) {
        guard ids.count >= 2 else { return }
        for (startID, endID) in zip(ids, ids.dropFirst()) {
            guard startID != endID else { continue }
            if hasLink(between: startID, and: endID, width: width, layerId: layerId, items: items) {
                continue
            }
            items.append(
                TraceSegment(
                    startID: startID,
                    endID: endID,
                    width: width,
                    layerId: layerId
                )
            )
        }
    }

    private func hasLink(
        between a: UUID,
        and b: UUID,
        width: CGFloat,
        layerId: UUID,
        items: [any CanvasItem]
    ) -> Bool {
        let links = items.compactMap { $0 as? TraceSegment }
        for link in links {
            let matchesDirection = (link.startID == a && link.endID == b)
                || (link.startID == b && link.endID == a)
            if matchesDirection && link.width == width && link.layerId == layerId {
                return true
            }
        }
        return false
    }

    private func position(for id: UUID, items: [any CanvasItem]) -> CGPoint? {
        items.compactMap { $0 as? TraceVertex }.first(where: { $0.id == id })?.position
    }

    private func applyNormalization(
        to items: inout [any CanvasItem],
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) {
        let points = items.compactMap { $0 as? TraceVertex }
        let links = items.compactMap { $0 as? TraceSegment }
        guard !points.isEmpty, !links.isEmpty else { return }

        let normalizationContext = ConnectionNormalizationContext(
            magnification: context.magnification,
            snapPoint: { point in
                context.snapProvider.snap(point: point, context: context, environment: environment)
            }
        )
        let delta = traceEngine.normalize(points: points, links: links, context: normalizationContext)
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
