import AppKit

final class HandleInteraction: CanvasInteraction {

    private enum State {
        case ready
        case draggingGraph(id: NodeID, handleKind: CanvasHandle.Kind, oppositeHandleWorldPosition: CGPoint?)
    }

    private var state: State = .ready
    private let handleScreenSize: CGFloat = 10.0

    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        return startGraphDrag(point: point, context: context)
    }

    private func startGraphDrag(point: CGPoint, context: RenderContext) -> Bool {
        let graph = context.graph
        guard graph.selection.count == 1, let id = graph.selection.first else { return false }
        guard let primitive = graph.component(AnyCanvasPrimitive.self, for: id) else { return false }

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

                self.state = .draggingGraph(
                    id: id,
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
        case .draggingGraph(let id, let handleKind, let oppositeWorldPosition):
            let graph = context.graph
            guard var primitive = graph.component(AnyCanvasPrimitive.self, for: id) else { return }

            let worldToLocalTransform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
                .inverted()
            let dragLocalPoint = point.applying(worldToLocalTransform)
            let oppositeLocalPoint = oppositeWorldPosition?.applying(worldToLocalTransform)

            primitive.updateHandle(handleKind, to: dragLocalPoint, opposite: oppositeLocalPoint)
            graph.setComponent(primitive, for: id)
        case .ready:
            break
        }
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        self.state = .ready
    }
}
