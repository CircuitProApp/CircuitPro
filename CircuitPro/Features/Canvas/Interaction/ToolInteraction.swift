import AppKit

/// Handles mouse clicks when a drawing tool (e.g., Line, Circle) is active.
struct ToolInteraction: CanvasInteraction {
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction is only interested if a drawing tool is active.
        if controller.selectedTool is CursorTool {
            return false
        }
        
        guard let tool = controller.selectedTool else {
            return false
        }
        
        print("[ToolInteraction] mouseDown: Starting with tool '\(tool.id)'.")
        
        
        // A tool might need to snap to existing geometry, so we perform a hit-test here.
        let tolerance = 5.0 / context.magnification
        let hitTarget = context.sceneRoot.hitTest(point, tolerance: tolerance)

        let snapService = SnapService(
            gridSize: context.environment.configuration.grid.spacing,
            isEnabled: context.environment.configuration.snapping.isEnabled
        )
        let snappedPoint = snapService.snap(point)
        
        let interactionContext = ToolInteractionContext(
            clickCount: NSApp.currentEvent?.clickCount ?? 1,
            hitTarget: hitTarget,
            renderContext: context
        )

        let result = tool.handleTap(at: snappedPoint, context: interactionContext)


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
