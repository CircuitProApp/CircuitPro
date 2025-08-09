import AppKit

/// An application-specific interaction handler that knows how to process results from schematic tools.
/// It acts as the orchestrator that translates tool intents into concrete model mutations.
struct ToolInteraction: CanvasInteraction {
    
    // CORRECT: No initializer or stored properties. It is fully generic.
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction is only interested in actions from drawing tools.
        guard let tool = controller.selectedTool, !(tool is CursorTool) else {
            return false
        }
        
        let tolerance = 5.0 / context.magnification
        let hitTarget = context.sceneRoot.hitTest(point, tolerance: tolerance)
        
        let interactionContext = ToolInteractionContext(
            clickCount: NSApp.currentEvent?.clickCount ?? 1,
            hitTarget: hitTarget,
            renderContext: context
        )

        let result = tool.handleTap(at: point, context: interactionContext)

        guard case .newNode(let newNode) = result else {
            return true
        }

        // --- THE CORRECT ORCHESTRATION LOGIC ---

        if let request = newNode as? WireRequestNode {
            // Find the one-and-only SchematicGraphNode in the scene.
            guard let schematicGraphNode = controller.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode else {
                assertionFailure("A wire connection was requested, but no SchematicGraphNode exists in the scene.")
                return true
            }

            // Perform the model mutation.
            let graph = schematicGraphNode.graph
            let startID = graph.getOrCreateVertex(at: request.from)
            let endID = graph.getOrCreateVertex(at: request.to)
            graph.connect(from: startID, to: endID, preferring: request.strategy)
          
            // Update the visuals.
            schematicGraphNode.syncChildNodesFromModel()
            // *** THIS IS THE FIX ***
            // The interaction's job is done. It reports to its manager (the controller)
            // that a persistent model was changed. It knows nothing about the document.
            controller.onModelDidChange?()

        } else {
            // Handle standard nodes.
            controller.sceneRoot.addChild(newNode)
            controller.onNodesChanged?(controller.sceneRoot.children)
            // A standard node was added, so we can also assume the model changed.
            controller.onModelDidChange?()
        }
        
        return true
    }
}
