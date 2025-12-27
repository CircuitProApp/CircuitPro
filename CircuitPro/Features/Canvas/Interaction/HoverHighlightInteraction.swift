import AppKit

/// Highlights elements under the cursor when the cursor tool is active.
final class HoverHighlightInteraction: CanvasInteraction {
    var wantsRawInput: Bool { true }

    func mouseMoved(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard controller.selectedTool is CursorTool else { return }
        guard context.graph != nil else {
            controller.setInteractionHighlight(nodeIDs: [])
            return
        }

        if let graphHit = GraphHitTester().hitTest(point: point, context: context) {
            controller.setInteractionHighlight(nodeIDs: [graphHit.rawValue])
        } else {
            controller.setInteractionHighlight(nodeIDs: [])
        }
    }
}
