import AppKit

/// An interaction that handles the dragging of a `Handle` on a `HandleEditable` node.
final class HandleInteraction: CanvasInteraction {

    private enum State {
        case ready
        /// - Parameters:
        ///   - node: A reference to the node being edited.
        ///   - handleKind: The kind of handle being dragged.
        ///   - oppositeHandleWorldPosition: The world-space position of the opposite handle, used to anchor resizing.
        case dragging(node: BaseNode & HandleEditable, handleKind: Handle.Kind, oppositeHandleWorldPosition: CGPoint?)
    }

    private var state: State = .ready
    private let handleScreenSize: CGFloat = 10.0

    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction only activates if a single, editable node is selected.
        guard controller.selectedNodes.count == 1,
              let node = controller.selectedNodes.first,
              let editableNode = node as? BaseNode & HandleEditable else {
            return false
        }

        // Check if the mouse click hit one of the node's handles.
        // We use the raw, unsnapped point for hit-testing for a more natural feel.
        for handle in editableNode.handles() {
            let worldHandlePosition = handle.position.applying(node.worldTransform)
            let toleranceInWorld = (handleScreenSize / 2.0) / context.magnification
            
            if point.distance(to: worldHandlePosition) <= toleranceInWorld {
                // A handle was hit. Enter the dragging state.
                var oppositeWorldPosition: CGPoint?
                if let oppositeKind = handle.kind.opposite,
                   let oppositeHandle = editableNode.handles().first(where: { $0.kind == oppositeKind }) {
                    // The opposite handle's position is in local space, so convert it to world space.
                    oppositeWorldPosition = oppositeHandle.position.applying(node.worldTransform)
                }
                
                self.state = .dragging(node: editableNode, handleKind: handle.kind, oppositeHandleWorldPosition: oppositeWorldPosition)
                return true // Consume the event to prevent other interactions.
            }
        }

        return false
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(let node, let handleKind, let oppositeWorldPosition) = state else { return }

        // Initialize the snap service from the environment.
        let snapService = SnapService(
            gridSize: context.environment.configuration.grid.spacing,
            isEnabled: context.environment.configuration.snapping.isEnabled
        )
        
        // Snap the incoming world-space mouse position to the grid.
        let snappedWorldPoint = snapService.snap(point)

        // The primitive's updateHandle method expects points in the node's local coordinate space.
        // We must convert the snapped world-space point into that local space.
        // This requires the inverse of the node's world transform.
        let worldToLocalTransform = node.worldTransform.inverted()
        let dragLocalPoint = snappedWorldPoint.applying(worldToLocalTransform)
        let oppositeLocalPoint = oppositeWorldPosition?.applying(worldToLocalTransform)
        
        // Pass the correctly-transformed local-space points to the node.
        var editableNode = node
        editableNode.updateHandle(handleKind, to: dragLocalPoint, opposite: oppositeLocalPoint)
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        // Exit the dragging state.
        self.state = .ready
    }
}
