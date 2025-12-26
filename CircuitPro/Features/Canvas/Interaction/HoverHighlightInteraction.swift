import AppKit

/// Highlights elements under the cursor when the cursor tool is active.
final class HoverHighlightInteraction: CanvasInteraction {
    var wantsRawInput: Bool { true }

    func mouseMoved(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard controller.selectedTool is CursorTool else { return }

        if let graphHit = GraphHitTester().hitTest(point: point, context: context) {
            controller.setInteractionHighlight(nodeIDs: [graphHit.rawValue])
            return
        }

        let tolerance = 5.0 / context.magnification
        if let hit = context.sceneRoot.hitTest(point, tolerance: tolerance),
           let highlightNode = highlightNode(for: hit) {
            controller.setInteractionHighlight(nodeIDs: [highlightNode.id])
        } else {
            controller.setInteractionHighlight(nodeIDs: [])
        }
    }

    private func highlightNode(for hit: CanvasHitTarget) -> BaseNode? {
        var candidate: BaseNode? = hit.node
        while let current = candidate {
            if current.isSelectable {
                return current
            }
            candidate = current.parent
        }
        return nil
    }
}
