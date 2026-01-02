import AppKit

/// Handles graph selection logic when the cursor is active.
struct SelectionInteraction: CanvasInteraction {

    var wantsRawInput: Bool { true }

    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedTool is CursorTool else {
            return false
        }

        let modifierFlags = event.modifierFlags

        if let graphHit = GraphHitTester().hitTest(point: point, context: context) {
            let resolvedHit = context.selectionTarget(for: graphHit)
            let graph = context.graph
            let currentSelectionIDs = graph.selection
            var newSelectionIDs = currentSelectionIDs

            if modifierFlags.contains(.shift) {
                if newSelectionIDs.contains(resolvedHit) {
                    newSelectionIDs.remove(resolvedHit)
                } else {
                    newSelectionIDs.insert(resolvedHit)
                }
            } else {
                newSelectionIDs = [resolvedHit]
            }

            if newSelectionIDs != currentSelectionIDs {
                graph.selection = newSelectionIDs
            }
        } else if !modifierFlags.contains(.shift), !context.graph.selection.isEmpty {
            context.graph.selection = []
        }
        return false
    }
}
