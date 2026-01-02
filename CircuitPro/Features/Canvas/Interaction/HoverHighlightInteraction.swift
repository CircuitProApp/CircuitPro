import AppKit

/// Highlights elements under the cursor when the cursor tool is active.
final class HoverHighlightInteraction: CanvasInteraction {
    var wantsRawInput: Bool { true }

    func mouseMoved(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard controller.selectedTool is CursorTool else { return }
        if let itemHit = ItemHitTester().hitTest(point: point, context: context) {
            let resolved = context.selectionTarget(for: itemHit)
            controller.setInteractionHighlight(elementIDs: [resolved])
        } else {
            controller.setInteractionHighlight(elementIDs: [])
        }
    }
}
