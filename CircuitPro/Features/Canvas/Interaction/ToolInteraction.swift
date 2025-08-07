import AppKit

/// An application-specific interaction handler that knows how to process results from schematic tools.
struct ToolInteraction: CanvasInteraction {

    // These are the dependencies the handler needs to perform its work.
    // They are provided by the SchematicView.
    var projectManager: ProjectManager
    var document: CircuitProjectDocument
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction is only interested if a drawing tool is active.
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

        // Only handle .newNode results.
        guard case .newNode(let newNode) = result else {
            return true // The tool handled the event, but we have no action to take.
        }

        // --- THE ORCHESTRATION LOGIC ---

        // 1. Check if the new node is our specific request message.
        if let request = newNode as? ConnectionRequestNode {
            
            // 2. Find the one-and-only SchematicGraphNode in the scene.
            guard let schematicGraphNode = controller.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode else {
                assertionFailure("A connection was requested, but no SchematicGraphNode exists in the scene.")
                return true
            }

            // 3. Perform the model mutation using data from the request.
            let graph = projectManager.schematicGraph
            let startID = graph.getOrCreateVertex(at: request.from)
            let endID = graph.getOrCreateVertex(at: request.to)
            graph.connect(from: startID, to: endID, preferring: request.strategy)
            
            // 4. Tell the graph node to rebuild its visual children.
            schematicGraphNode.syncChildNodesFromModel()

            // 5. Mark the document as dirty so it can be saved.
            document.updateChangeCount(.changeDone)

        } else {
            // 6. If it's not a request node, it's a standard visual node.
            // This path is not used by the ConnectionTool but could be by others.
            controller.sceneRoot.addChild(newNode)
            controller.onNodesChanged?(controller.sceneRoot.children)
        }
        
        return true
    }
}
