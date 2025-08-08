import AppKit

/// Handles marquee selection logic.
///
/// This interaction should be placed *after* `SelectionInteraction` in the stack.
/// It activates when a mouse down occurs on an empty area of the canvas, which
/// `SelectionInteraction` will have already processed by clearing the selection.
final class MarqueeInteraction: CanvasInteraction {

    private enum State {
        case ready
        /// - Parameters:
        ///   - origin: The starting point of the drag in canvas coordinates.
        ///   - isAdditive: Whether the user is holding Shift to add to the selection.
        ///   - initialSelection: The set of nodes that were selected when the drag began.
        case dragging(origin: CGPoint, isAdditive: Bool, initialSelection: [BaseNode])
    }

    private var state: State = .ready
    
    var wantsRawInput: Bool { true }

    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedTool is CursorTool else { return false }

        let tolerance = 5.0 / context.magnification
        if context.sceneRoot.hitTest(point, tolerance: tolerance) == nil {
            let isAdditive = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            
            // Store the selection state at the beginning of the drag.
            let initialSelection = controller.selectedNodes
            
            self.state = .dragging(origin: point, isAdditive: isAdditive, initialSelection: initialSelection)
            return true
        }

        return false
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(let origin, _, _) = state else { return }

        let marqueeRect = CGRect(origin: origin, size: .zero).union(CGRect(origin: point, size: .zero))
        
        controller.updateEnvironment {
            $0.marqueeRect = marqueeRect
        }

        let intersectingNodes = context.sceneRoot.nodes(intersecting: marqueeRect)
        
        let highlightedIDs = Set(intersectingNodes.map { $0.id })
        controller.setInteractionHighlight(nodeIDs: highlightedIDs)
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(_, let isAdditive, let initialSelection) = state else { return }

        // 1. Get the nodes that were highlighted by the marquee drag.
        let highlightedNodes = controller.interactionHighlightedNodeIDs.compactMap { id in
            controller.findNode(with: id, in: context.sceneRoot)
        }

        // 2. Calculate the final selection.
        if isAdditive {
            // Additive mode: Union of the initial selection and the marquee selection.
            let finalSelection = Set(initialSelection).union(Set(highlightedNodes))
            controller.setSelection(to: Array(finalSelection))
        } else {
            // Default mode: The marquee selection replaces the old selection.
            controller.setSelection(to: highlightedNodes)
        }
        
        // 3. Clean up state.
        self.state = .ready
        controller.updateEnvironment { $0.marqueeRect = nil }
        controller.setInteractionHighlight(nodeIDs: [])
    }
}
