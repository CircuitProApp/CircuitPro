import AppKit

/// Handles graph selection logic when the cursor is active.
struct SelectionInteraction: CanvasInteraction {

    var wantsRawInput: Bool { true }

    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedTool is CursorTool else {
            return false
        }

        let modifierFlags = event.modifierFlags

        if let itemHit = ItemHitTester().hitTest(point: point, context: context) {
            let currentSelectionIDs = context.selectedItemIDs
            var newSelectionIDs = currentSelectionIDs

            if modifierFlags.contains(.shift) {
                if newSelectionIDs.contains(itemHit) {
                    newSelectionIDs.remove(itemHit)
                } else {
                    newSelectionIDs.insert(itemHit)
                }
            } else {
                newSelectionIDs = [itemHit]
            }

            if newSelectionIDs != currentSelectionIDs {
                controller.updateSelection(newSelectionIDs)
            }
        } else if !modifierFlags.contains(.shift), !context.selectedItemIDs.isEmpty {
            controller.updateSelection([])
        }
        return false
    }
}
