import AppKit

/// Highlights elements under the cursor when the cursor tool is active.
final class HoverHighlightInteraction: CanvasInteraction {
    var wantsRawInput: Bool { true }

    func mouseMoved(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard controller.selectedTool is CursorTool else { return }
        if let itemHit = CanvasHitTester().hitTest(point: point, context: context) {
            controller.setInteractionHighlight(itemIDs: [itemHit])
        } else {
            controller.setInteractionHighlight(itemIDs: [])
        }
    }
}
