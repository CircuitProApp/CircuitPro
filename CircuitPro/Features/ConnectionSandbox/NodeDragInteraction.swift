import AppKit

final class NodeDragInteraction: CanvasInteraction {
    private struct DragState {
        let nodeID: UUID
        let origin: CGPoint
        let originalPosition: CGPoint
        let socketOrigins: [UUID: CGPoint]
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
            if let primitive = item as? AnyCanvasPrimitive {
                var socketOrigins: [UUID: CGPoint] = [:]
                for other in items {
                    if let socket = other as? Socket, socket.ownerID == primitive.id {
                        socketOrigins[socket.id] = socket.position
                    }
                }
                dragState = DragState(
                    nodeID: primitive.id,
                    origin: point,
                    originalPosition: primitive.position,
                    socketOrigins: socketOrigins
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
            if items[index].id == state.nodeID, var primitive = items[index] as? AnyCanvasPrimitive {
                primitive.position = newPosition
                items[index] = primitive
                continue
            }
            if var socket = items[index] as? Socket,
               let original = state.socketOrigins[socket.id] {
                socket.position = CGPoint(
                    x: original.x + snapped.dx,
                    y: original.y + snapped.dy
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
