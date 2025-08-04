import AppKit

final class ToolActionController {

    unowned let controller: CanvasController
    // We re-introduce the coordinator dependency, but ONLY to get the RenderContext.
    unowned let coordinator: WorkbenchInputCoordinator

    init(controller: CanvasController, coordinator: WorkbenchInputCoordinator) {
        self.controller = controller
        self.coordinator = coordinator
    }

    /// Handles a mouse down event when a tool other than the cursor is active.
    /// This now constructs a full `ToolInteractionContext` for the tool to use.
    /// - Returns: `true` if the tool consumed the event, `false` otherwise.
    func handleMouseDown(at point: CGPoint, hitTarget: CanvasHitTarget?, event: NSEvent) -> Bool {
        // Only handle events if a tool is active (and it's not the default cursor).
        guard var tool = controller.selectedTool, tool.id != "cursor" else {
            return false
        }
        
        let snappedPoint = controller.snap(point)
        
        // 1. Get the complete state of the canvas from the coordinator.
        let renderContext = coordinator.currentContext()
        
        // 2. Create the lightweight, specific context for THIS interaction.
        //    (This assumes ToolInteractionContext is updated to use CanvasHitResult?).
        let interactionContext = ToolInteractionContext(
            clickCount: event.clickCount,
            hitTarget: hitTarget,
            renderContext: renderContext
        )

        // 3. Call the tool with the correct interaction-specific context.
        //    (This assumes the CanvasTool protocol is updated).
        let result = tool.handleTap(at: snappedPoint, context: interactionContext)

        // 4. Handle the result from the tool based on the new architecture.
        switch result {
//        case .node(let newNode):
//            // Add the new node directly to the scene graph.
//            controller.sceneRoot.addChild(newNode)

        case .schematicModified:
            // The sync function will be refactored later.
            // controller.syncPinPositionsToGraph()
            break

        case .noResult:
            // The tool did something internally but produced no new content.
            break
        default:
            break
        }

        // The tool might have mutated its own state, so write it back.
        controller.selectedTool = tool
        controller.onUpdateSelectedTool?(tool)
        
        // If a tool was active, it always consumes the click.
        return true
    }
}
