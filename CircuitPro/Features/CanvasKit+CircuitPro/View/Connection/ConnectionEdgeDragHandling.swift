import AppKit
import SwiftUI

protocol ConnectionEdgeDragHandling {
    var isDragging: Bool { get }

    mutating func beginDrag(
        linkID: UUID,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        connectionPoints: [any ConnectionPoint],
        connectionLinks: [any ConnectionLink],
        connectionPointPositionsByID: [UUID: CGPoint],
        baseTolerance: CGFloat,
        liveLinkOrientation: inout [UUID: ConnectionSegmentOrientation]
    )

    mutating func updateDrag(
        delta: CanvasDragDelta,
        itemsBinding: Binding<[any CanvasItem]>,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        baseTolerance: CGFloat
    )

    mutating func endDrag() -> Bool
}
