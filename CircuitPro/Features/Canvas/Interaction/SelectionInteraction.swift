import AppKit

/// Handles node selection logic when the cursor is active.
struct SelectionInteraction: CanvasInteraction {

    var wantsRawInput: Bool { true }

    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedTool is CursorTool else {
            return false
        }

        let modifierFlags = event.modifierFlags

        if let graph = context.graph {
            if let graphHit = GraphHitTester().hitTest(point: point, context: context) {
                let currentSelectionIDs = graph.selection
                var newSelectionIDs = currentSelectionIDs

                if modifierFlags.contains(.shift) {
                    if newSelectionIDs.contains(graphHit) {
                        newSelectionIDs.remove(graphHit)
                    } else {
                        newSelectionIDs.insert(graphHit)
                    }
                } else {
                    newSelectionIDs = [graphHit]
                }

                if newSelectionIDs != currentSelectionIDs {
                    graph.selection = newSelectionIDs
                }

                if !modifierFlags.contains(.shift), !controller.selectedNodes.isEmpty {
                    controller.setSelection(to: [])
                }

                return false
            } else if !modifierFlags.contains(.shift), !graph.selection.isEmpty {
                graph.selection = []
            }
        }

        let currentSelection: [BaseNode] = controller.selectedNodes
        let tolerance = 5.0 / context.magnification
        var newSelection: [BaseNode] = currentSelection

        if let hit = context.sceneRoot.hitTest(point, tolerance: tolerance) {

            var nodeToSelect: BaseNode? = hit.node
            while let currentNode = nodeToSelect {
                if currentNode.isSelectable {
                    break
                }
                nodeToSelect = currentNode.parent
            }

            if let selectableNode = nodeToSelect {
                let isAlreadySelected = currentSelection.contains(where: { $0.id == selectableNode.id })

                if modifierFlags.contains(.shift) {
                    if let index = newSelection.firstIndex(where: { $0.id == selectableNode.id }) {
                        newSelection.remove(at: index)
                    } else {
                        newSelection.append(selectableNode)
                    }
                } else {
                    if !isAlreadySelected {
                        newSelection = [selectableNode]
                    }
                }

            } else {
                if !modifierFlags.contains(.shift) {
                    newSelection = []
                }
            }

        } else {
            if !modifierFlags.contains(.shift) {
                newSelection = []
            }
        }

        if Set(newSelection.map { $0.id }) != Set(currentSelection.map { $0.id }) {
            controller.setSelection(to: newSelection)
        }

        return false
    }
}
