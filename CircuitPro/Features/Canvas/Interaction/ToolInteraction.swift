import AppKit

/// Handles mouse clicks when a drawing tool (e.g., Line, Circle) is active.
struct ToolInteraction: CanvasInteraction {
    
    // The snapService property is no longer needed and should be deleted.
    // private let snapService = SnapService()
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction is only interested if a drawing tool is active.
        if controller.selectedTool is CursorTool {
            return false
        }
        
        guard let tool = controller.selectedTool else {
            return false
        }
        
        // A tool might need to snap to existing geometry, so we perform a hit-test here.
        // The `point` we use for hit-testing is already the final, processed point.
        let tolerance = 5.0 / context.magnification
        let hitTarget = context.sceneRoot.hitTest(point, tolerance: tolerance)
        
        let interactionContext = ToolInteractionContext(
            clickCount: NSApp.currentEvent?.clickCount ?? 1,
            hitTarget: hitTarget,
            renderContext: context
        )

        // Pass the `point` directly to the tool.
        let result = tool.handleTap(at: point, context: interactionContext)


        switch result {
        case .newNode(let newNode):
            controller.sceneRoot.addChild(newNode)
            controller.onNodesChanged?(controller.sceneRoot.children)
            
        case .noResult:
            break
        }
        return true
    }
}
