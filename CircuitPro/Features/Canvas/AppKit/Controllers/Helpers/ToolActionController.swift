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
        
        // --- THIS SECTION IS NOW FULLY CORRECTED ---

        let snappedPoint = controller.snap(point)
        let hitTarget = hitTestService.hitTest(point: snappedPoint)
        
        // Use the "compatibility shim" to create the legacy context for the tools.
        let legacyContext = CanvasToolContext(
            existingPinCount: controller.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 },
            existingPadCount: controller.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 },
            selectedLayer: controller.selectedLayer,
            magnification: controller.magnification,
            hitTarget: hitTarget,
            schematicGraph: controller.schematicGraph,
            clickCount: event.clickCount
        )

        // Call the tool with the correct legacy context.
        let result = tool.handleTap(at: snappedPoint, context: legacyContext)

        // --- END CORRECTION ---

        switch result {
        case .element(let newElement):
            controller.elements.append(newElement)
            // Push the change back up to SwiftUI!
            controller.onUpdateElements?(controller.elements)

        case .schematicModified:
            controller.syncPinPositionsToGraph()


        case .noResult:
            break
        }

        controller.selectedTool = tool
        // Push the tool state change back up to SwiftUI!
        controller.onUpdateSelectedTool?(tool)
        
        return true
    }
}
