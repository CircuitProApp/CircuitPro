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

        if let request = newNode as? WireRequestNode {
            // Handle schematic wire requests (existing logic)
            guard let wireEngine = context.environment.wireEngine else {
                return true
            }

            wireEngine.connect(from: request.from, to: request.to, preferring: request.strategy)
            return true

        } else if let request = newNode as? TraceRequestNode {
            // --- ADDED: Handle layout trace requests ---
            // 1. Find the TraceGraphNode in the scene, which holds our data model.
            guard let traceGraphNode = controller.sceneRoot.children.first(where: { $0 is TraceGraphNode }) as? TraceGraphNode else {
                assertionFailure("A trace was requested, but no TraceGraphNode exists in the scene.")
                return true
            }

            // 2. Get a reference to the actual TraceGraph model.
            let graph = traceGraphNode.graph

            // 3. Use the data from the request node to update the model.
            graph.addTrace(
                path: request.points,
                width: request.width,
                layerId: request.layerId
            )

            // 4. Tell the graph node to update its visual children from the model.
            // We now pass the canvas layers from the render context, so the
            // new TraceNodes can have their colors resolved correctly.
            traceGraphNode.syncChildNodesFromModel(canvasLayers: context.layers)

            return true

        } else {
            // Handle standard nodes that are not requests.
            if let primitiveNode = newNode as? PrimitiveNode, let graph = context.graph {
                let nodeID = NodeID(primitiveNode.id)
                graph.addNode(nodeID)
                graph.setComponent(primitiveNode.primitive, for: nodeID)
                return true
            }
            if let store = context.environment.canvasStore {
                Task { @MainActor in
                    store.addNode(newNode)
                }
            }
            controller.sceneRoot.addChild(newNode)
        }

        return true
    }
}
