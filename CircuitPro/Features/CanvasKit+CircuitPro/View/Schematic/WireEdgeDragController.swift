import AppKit
import SwiftUI

struct WireEdgeDragController: ConnectionEdgeDragHandling {
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
        guard let link = connectionLinks.first(where: { $0.id == linkID }),
            let start = connectionPointPositionsByID[link.startID],
            let end = connectionPointPositionsByID[link.endID]
        else { return }

        let linkOrientation = ConnectionInteractionSupport.buildOrientationMap(
            for: connectionLinks,
            positions: connectionPointPositionsByID,
            tolerance: tolerance,
            mode: .orthogonal,
            cache: &liveLinkOrientation
        )
        let adjacency = ConnectionInteractionSupport.linkAdjacency(for: connectionLinks)
        let linkEndpoints = ConnectionInteractionSupport.linkEndpointMap(for: connectionLinks)
        let fixedPointIDs = ConnectionInteractionSupport.fixedPointIDs(
            in: connectionPoints,
            movablePoint: WireVertex.self
        )

        dragState = DragState(
            edgeID: linkID,
            startID: link.startID,
            endID: link.endID,
            origin: environment.processedMouseLocation ?? context.mouseLocation ?? .zero,
            startPosition: start,
            endPosition: end,
            originalPositions: connectionPointPositionsByID,
            linkOrientation: linkOrientation,
            adjacency: adjacency,
            linkEndpoints: linkEndpoints,
            fixedPointIDs: fixedPointIDs
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

        _ = detachIfNeeded(
            endpointID: state.startID,
            orientation: state.linkOrientation[state.edgeID],
            snapped: snapped,
            tolerance: tolerance,
            state: &state,
            items: &items,
            replacingStart: true
        )

        _ = detachIfNeeded(
            endpointID: state.endID,
            orientation: state.linkOrientation[state.edgeID],
            snapped: snapped,
            tolerance: tolerance,
            state: &state,
            items: &items,
            replacingStart: false
        )

        let newStart = CGPoint(
            x: state.startPosition.x + snapped.dx,
            y: state.startPosition.y + snapped.dy
        )
        let newEnd = CGPoint(
            x: state.endPosition.x + snapped.dx,
            y: state.endPosition.y + snapped.dy
        )

        var newPositions = state.originalPositions
        if !state.fixedPointIDs.contains(state.startID) {
            newPositions[state.startID] = newStart
        }
        if !state.fixedPointIDs.contains(state.endID) {
            newPositions[state.endID] = newEnd
        }

        ConnectionInteractionSupport.applyConstraints(
            movedIDs: [state.startID, state.endID].filter { !state.fixedPointIDs.contains($0) },
            positions: &newPositions,
            originalPositions: state.originalPositions,
            adjacency: state.adjacency,
            orientations: state.linkOrientation,
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

    mutating func endDrag() -> Bool {
        let wasDragging = dragState != nil
        dragState = nil
        return wasDragging
    }

    private mutating func detachIfNeeded(
        endpointID: UUID,
        orientation: ConnectionSegmentOrientation?,
        snapped: CGVector,
        tolerance: CGFloat,
        state: inout DragState,
        items: inout [any CanvasItem],
        replacingStart: Bool
    ) -> Bool {
        guard state.fixedPointIDs.contains(endpointID),
            let orientation
        else { return false }

        let isOffAxis = ConnectionInteractionSupport.shouldDetachFixedEndpoint(
            for: snapped,
            orientation: orientation,
            tolerance: tolerance
        )
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

        let links = items.compactMap { $0 as? any ConnectionLink }
        if !ConnectionInteractionSupport.hasLink(
            between: endpointID,
            and: newVertex.id,
            links: links
        ) {
            items.append(WireSegment(startID: endpointID, endID: newVertex.id))
            let newOrientation: ConnectionSegmentOrientation =
                (orientation == .horizontal)
                ? .vertical
                : (orientation == .vertical ? .horizontal : .arbitrary)
            if let newLink = items.last as? WireSegment {
                state.linkOrientation[newLink.id] = newOrientation
            }
        }

        let updatedLinks = items.compactMap { $0 as? any ConnectionLink }
        state.adjacency = ConnectionInteractionSupport.linkAdjacency(for: updatedLinks)
        state.linkEndpoints = ConnectionInteractionSupport.linkEndpointMap(for: updatedLinks)
        state.linkOrientation[state.edgeID] = orientation
        return true
    }

    private struct DragState {
        let edgeID: UUID
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
