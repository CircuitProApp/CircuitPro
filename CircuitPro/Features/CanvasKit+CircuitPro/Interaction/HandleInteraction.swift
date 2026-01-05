import AppKit

final class HandleInteraction: CanvasInteraction {

    private enum State {
        case ready
        case draggingItems(id: UUID, handleKind: CanvasHandle.Kind, oppositeHandleWorldPosition: CGPoint?)
    }

    private var state: State = .ready
    private let handleScreenSize: CGFloat = 10.0

    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        return startItemDrag(point: point, context: context)
    }

    private func startItemDrag(point: CGPoint, context: RenderContext) -> Bool {
        guard let itemsBinding = context.environment.items else { return false }
        guard context.selectedItemIDs.count == 1, let selectedID = context.selectedItemIDs.first else { return false }
        guard let primitive = itemsBinding.wrappedValue.first(where: {
            $0.id == selectedID && $0 is AnyCanvasPrimitive
        }) as? AnyCanvasPrimitive else {
            return false
        }

        for handle in primitive.handles() {
            let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            let worldHandlePosition = handle.position.applying(transform)
            let toleranceInWorld = (handleScreenSize / 2.0) / context.magnification

            if point.distance(to: worldHandlePosition) <= toleranceInWorld {
                var oppositeWorldPosition: CGPoint?
                if let oppositeKind = handle.kind.opposite,
                   let oppositeHandle = primitive.handles().first(where: { $0.kind == oppositeKind }) {
                    oppositeWorldPosition = oppositeHandle.position.applying(transform)
                }

                self.state = .draggingItems(
                    id: selectedID,
                    handleKind: handle.kind,
                    oppositeHandleWorldPosition: oppositeWorldPosition
                )
                return true
            }
        }

        return false
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        switch state {
        case .draggingItems(let id, let handleKind, let oppositeWorldPosition):
            guard let itemsBinding = context.environment.items else { return }
            var items = itemsBinding.wrappedValue
            guard let index = items.firstIndex(where: { $0.id == id }),
                  var primitive = items[index] as? AnyCanvasPrimitive
            else { return }

            let worldToLocalTransform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
                .inverted()
            let dragLocalPoint = point.applying(worldToLocalTransform)
            let oppositeLocalPoint = oppositeWorldPosition?.applying(worldToLocalTransform)

            primitive.updateHandle(handleKind, to: dragLocalPoint, opposite: oppositeLocalPoint)
            items[index] = primitive
            itemsBinding.wrappedValue = items
        case .ready:
            break
        }
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        self.state = .ready
    }
}
