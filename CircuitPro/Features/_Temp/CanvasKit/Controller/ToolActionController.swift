import AppKit

final class ToolActionController {

    unowned let controller: CanvasController
    // The coordinator provides access to the full canvas state (RenderContext).
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
        let interactionContext = ToolInteractionContext(
            clickCount: event.clickCount,
            hitTarget: hitTarget,
            renderContext: renderContext
        )

        // 3. Call the tool with the correct interaction-specific context.
        let result = tool.handleTap(at: snappedPoint, context: interactionContext)

        // 4. Handle the result from the tool based on the new architecture.
        switch result {
        case .newNode(let newNode):
            // Step 4a: Add the new node to the live scene graph.
            controller.sceneRoot.addChild(newNode)
            
            // Step 4b: Propagate this change back to the SwiftUI source of truth.
            controller.onNodesChanged?(controller.sceneRoot.children)

        case .schematicModified:
            // The sync function will be refactored later.
            // controller.syncPinPositionsToGraph()
            break

        case .noResult:
            // The tool did something internally but produced no new content.
            // This is for multi-step tools, like the first click of the rectangle tool.
            break
        }

        // The tool might have mutated its own state (e.g., storing the first click point),
        // so we need to write that updated state back to the controller.
        controller.selectedTool = tool
        controller.onUpdateSelectedTool?(tool)
        
        // If a tool was active, it always consumes the click event.
        return true
    }
}
