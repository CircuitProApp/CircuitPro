import AppKit
import SwiftUI

/// An application-specific interaction handler that knows how to process results from schematic tools.
/// It acts as the orchestrator that translates tool intents into concrete model mutations.
struct ToolInteraction: CanvasInteraction {

    // MODIFIED: The method signature now matches the CanvasInteraction protocol.
    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction is only interested in actions from drawing tools.
        guard let tool = controller.selectedTool, !(tool is CursorTool) else {
            return false
        }

        // MODIFIED: It's safer to get the click count from the passed-in event.
        let interactionContext = ToolInteractionContext(
            clickCount: event.clickCount,
            renderContext: context
        )

        let result = tool.handleTap(at: point, context: interactionContext)

        switch result {
        case .noResult:
            // If the tool handled the tap but didn't create a new node (e.g., the
            // first click of a line tool), we should still consume the mouse event.
            return true
        case .newItem(let item):
            if let itemsBinding = context.environment.items {
                var items = itemsBinding.wrappedValue
                items.append(item)
                itemsBinding.wrappedValue = items
                return true
            } else {
                let graph = context.graph
                let nodeID = NodeID(item.id)
                if !graph.nodes.contains(nodeID) {
                    graph.addNode(nodeID)
                }
                graph.setComponent(item, for: nodeID)
                return true
            }
        }
    }
}
