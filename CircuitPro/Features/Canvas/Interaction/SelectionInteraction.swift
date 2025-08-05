import AppKit

/// Handles node selection logic when the cursor is active.
struct SelectionInteraction: CanvasInteraction {
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction only runs when the selection tool is active.
        guard controller.selectedTool is CursorTool else {
            return false
        }
        
        let currentSelection = controller.selectedNodes
        let tolerance = 5.0 / context.magnification
        let modifierFlags = NSApp.currentEvent?.modifierFlags ?? []
        
        var newSelection = currentSelection
        
        // --- THIS IS THE NEW LOGIC ---
        
        // 1. Perform a standard hit-test to see if we clicked on *anything*.
        if let hit = context.sceneRoot.hitTest(point, tolerance: tolerance) {
            // 2. We hit a node. Now, find the actual object we should select by
            //    traversing up the hierarchy from the hit node.
            var nodeToSelect: (any CanvasNode)? = hit.node
            while let currentNode = nodeToSelect {
                if currentNode.isSelectable {
                    break // We found our target, exit the loop.
                }
                // Move up to the parent and try again.
                nodeToSelect = currentNode.parent
            }

            // 3. If we found a selectable node, apply the selection rules.
            if let selectableNode = nodeToSelect {
                let isAlreadySelected = currentSelection.contains(where: { $0.id == selectableNode.id })
                
                if modifierFlags.contains(.shift) {
                    // Shift-click: Toggle the selection state of this node.
                    if let index = newSelection.firstIndex(where: { $0.id == selectableNode.id }) {
                        newSelection.remove(at: index)
                    } else {
                        newSelection.append(selectableNode)
                    }
                } else {
                    // Normal click: If not already part of the selection, select it exclusively.
                    if !isAlreadySelected {
                        newSelection = [selectableNode]
                    }
                    // If it *is* already selected, we do nothing, allowing a subsequent drag operation.
                }

            } else {
                // We hit something, but neither it nor any of its ancestors were selectable.
                // Treat this the same as clicking on empty space.
                if !modifierFlags.contains(.shift) {
                    newSelection = []
                }
            }
            
        } else {
            // Case 4: Clicked on empty space. Deselect all if not shift-clicking.
            if !modifierFlags.contains(.shift) {
                newSelection = []
            }
        }
        
        // Update the controller only if the selection has actually changed.
        if Set(newSelection.map { $0.id }) != Set(currentSelection.map { $0.id }) {
            controller.setSelection(to: newSelection)
        }
        
        // IMPORTANT: Always return false to allow other interactions (like DragInteraction)
        // to process this same mouse event.
        return false
    }
}
