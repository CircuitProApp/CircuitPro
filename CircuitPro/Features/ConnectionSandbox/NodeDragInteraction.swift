import AppKit

final class NodeDragInteraction: CanvasInteraction {
    private struct DragState {
        let nodeID: UUID
        let origin: CGPoint
        let originalPosition: CGPoint
        let socketOffsets: [UUID: CGPoint]
    }

    private var dragState: DragState?

    func mouseDown(
        with event: NSEvent,
        at point: CGPoint,
        context: RenderContext,
        controller: CanvasController
    ) -> Bool {
        dragState = nil
        guard let itemsBinding = context.environment.items else { return false }

        guard let hit = CanvasHitTester().hitTest(point: point, context: context) else {
            return false
        }

        let items = itemsBinding.wrappedValue
        for item in items where item.id == hit {
            if let node = item as? SandboxNode {
                dragState = DragState(
                    nodeID: node.id,
                    origin: point,
                    originalPosition: node.position,
                    socketOffsets: node.socketOffsets
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
        let newPosition = CGPoint(
            x: state.originalPosition.x + snapped.dx,
            y: state.originalPosition.y + snapped.dy
        )

        var items = itemsBinding.wrappedValue
        for index in items.indices {
            if items[index].id == state.nodeID, var node = items[index] as? SandboxNode {
                node.position = newPosition
                items[index] = node
                continue
            }
            if var socket = items[index] as? Socket,
               socket.ownerID == state.nodeID,
               let offset = state.socketOffsets[socket.id] {
                socket.position = CGPoint(
                    x: newPosition.x + offset.x,
                    y: newPosition.y + offset.y
                )
                items[index] = socket
            }
        }
        itemsBinding.wrappedValue = items
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        dragState = nil
    }
}
