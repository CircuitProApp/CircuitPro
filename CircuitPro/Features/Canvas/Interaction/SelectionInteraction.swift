import AppKit

/// Handles node selection logic when the cursor is active.
struct SelectionInteraction: CanvasInteraction {
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction only runs when the selection tool is active.
        guard controller.selectedTool is CursorTool else {
            return false
        }
        
        // --- All types are now concrete `BaseNode`
        
        let currentSelection: [BaseNode] = controller.selectedNodes
        let tolerance = 5.0 / context.magnification
        let modifierFlags = NSApp.currentEvent?.modifierFlags ?? []
        
        var newSelection: [BaseNode] = currentSelection
        
        // 1. Perform a standard hit-test. `hit.node` is now a `BaseNode`.
        if let hit = context.sceneRoot.hitTest(point, tolerance: tolerance) {
            
            // 2. We hit a node. Now, find the actual object we should select by
            //    traversing up the hierarchy. `nodeToSelect` is now `BaseNode?`.
            var nodeToSelect: BaseNode? = hit.node
            while let currentNode = nodeToSelect {
                if currentNode.isSelectable {
                    break // We found our target.
                }
                // Move up to the parent. This is clean because `currentNode.parent` is also `BaseNode?`.
                nodeToSelect = currentNode.parent
            }

            // 3. If we found a selectable node, apply the selection rules.
            if let selectableNode = nodeToSelect {
                let isAlreadySelected = currentSelection.contains(where: { $0.id == selectableNode.id })
                
                if modifierFlags.contains(.shift) {
                    // Shift-click: Toggle the selection state.
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
                    // If it *is* already selected, do nothing, allowing a subsequent drag operation.
                }

            } else {
                // We hit an unselectable part of the scene graph.
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
            // `setSelection` now expects `[BaseNode]`, so this works perfectly.
            controller.setSelection(to: newSelection)
        }
        
        // Always return false to allow other interactions (like Drag) to act on this same click.
        return false
    }
}
