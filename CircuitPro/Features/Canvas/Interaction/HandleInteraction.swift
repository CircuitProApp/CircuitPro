import AppKit

final class HandleInteraction: CanvasInteraction {

    private enum State {
        case ready
        case dragging(node: BaseNode & HandleEditable, handleKind: CanvasHandle.Kind, oppositeHandleWorldPosition: CGPoint?)
        case draggingGraph(id: NodeID, handleKind: CanvasHandle.Kind, oppositeHandleWorldPosition: CGPoint?)
    }

    private var state: State = .ready
    private let handleScreenSize: CGFloat = 10.0

    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedNodes.count == 1,
              let node = controller.selectedNodes.first,
              let editableNode = node as? BaseNode & HandleEditable else {
            return startGraphDrag(point: point, context: context)
        }

        for handle in editableNode.handles() {
            let worldHandlePosition = handle.position.applying(node.worldTransform)
            let toleranceInWorld = (handleScreenSize / 2.0) / context.magnification

            if point.distance(to: worldHandlePosition) <= toleranceInWorld {
                var oppositeWorldPosition: CGPoint?
                if let oppositeKind = handle.kind.opposite,
                   let oppositeHandle = editableNode.handles().first(where: { $0.kind == oppositeKind }) {
                    oppositeWorldPosition = oppositeHandle.position.applying(node.worldTransform)
                }

                self.state = .dragging(node: editableNode, handleKind: handle.kind, oppositeHandleWorldPosition: oppositeWorldPosition)
                return true
            }
        }

        return false
    }

    private func startGraphDrag(point: CGPoint, context: RenderContext) -> Bool {
        guard let graph = context.graph else { return false }
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
        case .dragging(let node, let handleKind, let oppositeWorldPosition):
            let worldToLocalTransform = node.worldTransform.inverted()
            let dragLocalPoint = point.applying(worldToLocalTransform)
            let oppositeLocalPoint = oppositeWorldPosition?.applying(worldToLocalTransform)

            var editableNode = node
            editableNode.updateHandle(handleKind, to: dragLocalPoint, opposite: oppositeLocalPoint)

            if let primitiveNode = editableNode as? PrimitiveNode, let graph = context.graph {
                graph.setComponent(primitiveNode.primitive, for: NodeID(primitiveNode.id))
            }
        case .draggingGraph(let id, let handleKind, let oppositeWorldPosition):
            guard let graph = context.graph,
                  var primitive = graph.component(AnyCanvasPrimitive.self, for: id) else { return }

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
