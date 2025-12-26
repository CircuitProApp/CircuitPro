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

        switch result {
        case .noResult:
            // If the tool handled the tap but didn't create a new node (e.g., the
            // first click of a line tool), we should still consume the mouse event.
            return true
        case .command(let command):
            command.execute(context: interactionContext, controller: controller)
            return true

        case .newNode(let newNode):
            // Handle standard nodes that are not requests.
            if let primitiveNode = newNode as? PrimitiveNode {
                guard let graph = context.graph else {
                    assertionFailure("Primitive nodes must be routed through the graph.")
                    return true
                }
                let nodeID = NodeID(primitiveNode.id)
                if !graph.nodes.contains(nodeID) {
                    graph.addNode(nodeID)
                }
                graph.setComponent(primitiveNode.primitive, for: nodeID)
                return true
            }

            if let store = context.environment.canvasStore {
                Task { @MainActor in
                    store.addNode(newNode)
                }
            }
            controller.sceneRoot.addChild(newNode)
            return true

        case .newPrimitive(let primitive):
            guard let graph = context.graph else {
                assertionFailure("Primitives require a graph-backed canvas.")
                return true
            }
            let nodeID = NodeID(primitive.id)
            if !graph.nodes.contains(nodeID) {
                graph.addNode(nodeID)
            }
            graph.setComponent(primitive, for: nodeID)
            return true
        }
    }
}
