import AppKit
import SwiftUI

struct TraceEdgeDragController: ConnectionEdgeDragHandling {
    private var dragState: DragState?

    var isDragging: Bool {
        dragState != nil
    }

    mutating func beginDrag(
        linkID: UUID,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        connectionPoints: [any ConnectionPoint],
        connectionLinks: [any ConnectionLink],
        connectionPointPositionsByID: [UUID: CGPoint],
        baseTolerance: CGFloat,
        liveLinkOrientation: inout [UUID: ConnectionSegmentOrientation]
    ) {
        dragState = nil

        let tolerance = baseTolerance / max(context.magnification, 0.001)
        guard let link = connectionLinks.first(where: { $0.id == linkID }) as? TraceSegment,
            let start = connectionPointPositionsByID[link.startID],
            let end = connectionPointPositionsByID[link.endID]
        else { return }

        let orientations = ConnectionInteractionSupport.buildOrientationMap(
            for: connectionLinks,
            positions: connectionPointPositionsByID,
            tolerance: tolerance,
            mode: .octilinear,
            cache: &liveLinkOrientation
        )

        dragState = DragState(
            edgeID: linkID,
            layerId: link.layerId,
            startID: link.startID,
            endID: link.endID,
            origin: environment.processedMouseLocation ?? context.mouseLocation ?? .zero,
            startPosition: start,
            endPosition: end,
            originalPositions: connectionPointPositionsByID,
            linkOrientation: orientations,
            adjacency: ConnectionInteractionSupport.linkAdjacency(for: connectionLinks),
            linkEndpoints: ConnectionInteractionSupport.linkEndpointMap(for: connectionLinks),
            fixedPointIDs: ConnectionInteractionSupport.fixedPointIDs(
                in: connectionPoints,
                movablePoint: TraceVertex.self
            )
        )
    }

    mutating func updateDrag(
        delta: CanvasDragDelta,
        itemsBinding: Binding<[any CanvasItem]>,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        baseTolerance: CGFloat
    ) {
        guard var state = dragState else { return }

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
        var orientationCache = state.linkOrientation
        let startOrientation = state.linkOrientation[state.edgeID]
        let endOrientation = state.linkOrientation[state.edgeID]

        _ = Self.detachIfNeeded(
            endpointID: state.startID,
            orientation: startOrientation,
            snapped: snapped,
            tolerance: tolerance,
            state: &state,
            items: &items,
            replacingStart: true,
            liveLinkOrientation: &orientationCache
        )

        _ = Self.detachIfNeeded(
            endpointID: state.endID,
            orientation: endOrientation,
            snapped: snapped,
            tolerance: tolerance,
            state: &state,
            items: &items,
            replacingStart: false,
            liveLinkOrientation: &orientationCache
        )
        state.linkOrientation = orientationCache

        let layerSegments = connectionLinks(in: items, on: state.layerId)
        let solverDeltas = TraceSegmentDragSolver.solve(
            draggedID: state.edgeID,
            startID: state.startID,
            endID: state.endID,
            delta: snapped,
            originalPositions: state.originalPositions,
            layerSegments: layerSegments,
            orientations: state.linkOrientation,
            fixedPointIDs: state.fixedPointIDs
        )

        var newPositions = state.originalPositions
        for (id, pos) in solverDeltas {
            newPositions[id] = pos
        }

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

    mutating func endDrag() -> Bool {
        let wasDragging = dragState != nil
        dragState = nil
        return wasDragging
    }

    private static func detachIfNeeded(
        endpointID: UUID,
        orientation: ConnectionSegmentOrientation?,
        snapped: CGVector,
        tolerance: CGFloat,
        state: inout DragState,
        items: inout [any CanvasItem],
        replacingStart: Bool,
        liveLinkOrientation: inout [UUID: ConnectionSegmentOrientation]
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
            uniqueKeysWithValues: items.compactMap { $0 as? TraceVertex }.map {
                ($0.id, $0.position)
            }
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

    private func connectionLinks(in items: [any CanvasItem], on layerId: UUID) -> [TraceSegment] {
        items.compactMap { $0 as? TraceSegment }.filter { $0.layerId == layerId }
    }

    private struct DragState {
        let edgeID: UUID
        let layerId: UUID
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
