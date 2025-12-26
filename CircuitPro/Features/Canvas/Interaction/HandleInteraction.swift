import AppKit

final class HandleInteraction: CanvasInteraction {

    private enum State {
        case ready
        case dragging(node: BaseNode & HandleEditable, handleKind: CanvasHandle.Kind, oppositeHandleWorldPosition: CGPoint?)
    }

    private var state: State = .ready
    private let handleScreenSize: CGFloat = 10.0

    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedNodes.count == 1,
              let node = controller.selectedNodes.first,
              let editableNode = node as? BaseNode & HandleEditable else {
            return false
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

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(let node, let handleKind, let oppositeWorldPosition) = state else { return }

        let worldToLocalTransform = node.worldTransform.inverted()
        let dragLocalPoint = point.applying(worldToLocalTransform)
        let oppositeLocalPoint = oppositeWorldPosition?.applying(worldToLocalTransform)

        var editableNode = node
        editableNode.updateHandle(handleKind, to: dragLocalPoint, opposite: oppositeLocalPoint)

        if let primitiveNode = editableNode as? PrimitiveNode, let graph = context.graph {
            graph.setComponent(primitiveNode.primitive, for: NodeID(primitiveNode.id))
        }
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        self.state = .ready
    }
}
