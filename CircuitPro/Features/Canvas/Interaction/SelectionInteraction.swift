import AppKit

/// Handles node selection logic when the cursor is active.
struct SelectionInteraction: CanvasInteraction {
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        
        // --- THIS IS THE FIX ---
        // We now check if the active tool is an instance of the CursorTool class.
        // This interaction is only interested in running when the selection tool is active.
        guard controller.selectedTool is CursorTool else {
            return false
        }
        
        // The rest of the logic remains the same, as it was already correct.
        let currentSelection = controller.selectedNodes
        let tolerance = 5.0 / context.magnification
        let hitTarget = context.sceneRoot.hitTest(point, tolerance: tolerance)
        let modifierFlags = NSApp.currentEvent?.modifierFlags ?? []
        
        var newSelection = currentSelection
        
        if let hit = hitTarget, let hitID = hit.selectableID {
            // Case 1: Clicked on an object.
            
            if modifierFlags.contains(.shift) {
                // Shift-click: toggle the item's selection state.
                if let index = newSelection.firstIndex(where: { $0.id == hitID }) {
                    newSelection.remove(at: index)
                } else if let node = controller.findNode(with: hitID, in: controller.sceneRoot) {
                    newSelection.append(node)
                }
            } else {
                // Normal click: select only this item if it's not already selected.
                if !currentSelection.contains(where: { $0.id == hitID }) {
                    if let node = controller.findNode(with: hitID, in: controller.sceneRoot) {
                         newSelection = [node]
                    }
                }
            }
            
        } else {
            // Case 2: Clicked on empty space.
            if !modifierFlags.contains(.shift) && !currentSelection.isEmpty {
                newSelection = []
            }
        }
        
        let currentSelectionIDs = Set(currentSelection.map { $0.id })
        let newSelectionIDs = Set(newSelection.map { $0.id })

        if newSelectionIDs != currentSelectionIDs {
            // If the selection has changed, update the controller.
            controller.setSelection(to: newSelection)
        }
        
        // IMPORTANT: Always return false.
        // This allows other interactions (like Drag) to act on this same click.
        return false
    }
}
