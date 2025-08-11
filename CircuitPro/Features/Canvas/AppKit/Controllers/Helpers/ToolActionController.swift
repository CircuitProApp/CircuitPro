import AppKit

final class ToolActionController {

    unowned let controller: CanvasController
    unowned let hitTestService: WorkbenchInputCoordinator

    init(controller: CanvasController, hitTestService: WorkbenchInputCoordinator) {
        self.controller = controller
        self.hitTestService = hitTestService
    }

    func handleMouseDown(at point: CGPoint, event: NSEvent) -> Bool {
        guard var tool = controller.selectedTool, tool.id != "cursor" else {
            return false
        }
        
        // --- This is the final, clean implementation ---

        let snappedPoint = controller.snap(point)
        
        // 1. Get the complete state of the canvas for rendering reference.
        let renderContext = hitTestService.currentContext()
        
        // 2. Perform the event-specific hit-test.
        let hitTarget = hitTestService.hitTest(point: snappedPoint)

        // 3. Create the lightweight, specific context for THIS interaction.
        let interactionContext = ToolInteractionContext(
            clickCount: event.clickCount,
            hitTarget: hitTarget,
            renderContext: renderContext
        )

        // 4. Call the tool with the correct interaction-specific context.
        // (This requires the CanvasTool protocol to be updated).
        let result = tool.handleTap(at: snappedPoint, context: interactionContext)

        // --- End of new implementation ---

        switch result {
        case .element(let newElement):
            controller.elements.append(newElement)
            controller.onUpdateElements?(controller.elements)

        case .schematicModified:
            controller.syncPinPositionsToGraph()

        case .noResult:
            break
        }

        controller.selectedTool = tool
        controller.onUpdateSelectedTool?(tool)
        
        return true
    }
}
