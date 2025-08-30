import AppKit

/// An application-specific interaction handler that knows how to process results from schematic tools.
/// It acts as the orchestrator that translates tool intents into concrete model mutations.
struct ToolInteraction: CanvasInteraction {
    
    // MODIFIED: The method signature now matches the CanvasInteraction protocol.
    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction is only interested in actions from drawing tools.
        guard let tool = controller.selectedTool, !(tool is CursorTool) else {
            return false
        }
        
        let tolerance = 5.0 / context.magnification
        let hitTarget = context.sceneRoot.hitTest(point, tolerance: tolerance)
        
        // MODIFIED: It's safer to get the click count from the passed-in event.
        let interactionContext = ToolInteractionContext(
            clickCount: event.clickCount,
            hitTarget: hitTarget,
            renderContext: context
        )

        let result = tool.handleTap(at: point, context: interactionContext)

        guard case .newNode(let newNode) = result else {
            // If the tool handled the tap but didn't create a new node (e.g., the
            // first click of a line tool), we should still consume the mouse event.
            return true
        }

        // --- Orchestration logic is unchanged ---

        if let request = newNode as? WireRequestNode {
            guard let schematicGraphNode = controller.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode else {
                assertionFailure("A wire connection was requested, but no SchematicGraphNode exists in the scene.")
                return true
            }

            let graph = schematicGraphNode.graph
            graph.connect(from: request.from, to: request.to, preferring: request.strategy)

            schematicGraphNode.syncChildNodesFromModel()
            controller.onModelDidChange?()
            return true
        } else {
            // Handle standard nodes.
            controller.sceneRoot.addChild(newNode)
            controller.onNodesChanged?(controller.sceneRoot.children)
            controller.onModelDidChange?()
        }
        
        return true
    }
}
