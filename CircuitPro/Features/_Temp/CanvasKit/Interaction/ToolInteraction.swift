import AppKit

/// Handles mouse clicks when a drawing tool (e.g., Line, Circle) is active.
struct ToolInteraction: CanvasInteraction {
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction is only interested if a drawing tool is active.
        guard var tool = controller.selectedTool, tool.id != "cursor" else {
            return false
        }
        
        print("[ToolInteraction] mouseDown: Starting with tool '\(tool.id)'.")
        
        
        // A tool might need to snap to existing geometry, so we perform a hit-test here.
        let tolerance = 5.0 / context.magnification
        let hitTarget = context.sceneRoot.hitTest(point, tolerance: tolerance)

        // --- THIS IS THE FIX ---
        // We call the `value(for:)` method and let Swift infer the type.
        // The `SnapService` initializer expects a `CGFloat` and a `Bool`, and the
        // nil-coalescing operator `??` provides a default value of the same type.
        // This gives the compiler enough context to infer that `T` is `CGFloat` and `Bool` respectively.
        let snapService = SnapService(
            gridSize: context.value(for: "snapGridSize") ?? 10.0,
            isEnabled: context.value(for: "isSnappingEnabled") ?? true
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
            
        case .schematicModified, .noResult:
            break
        }
        return true
    }
}
