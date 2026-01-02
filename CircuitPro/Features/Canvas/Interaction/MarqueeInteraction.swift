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
        case dragging(origin: CGPoint, isAdditive: Bool, initialGraphSelection: Set<GraphElementID>)
    }

    private var state: State = .ready

    var wantsRawInput: Bool { true }

    // MODIFIED: Updated method signature to accept NSEvent.
    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedTool is CursorTool else { return false }

        let graph = context.graph
        if ItemHitTester().hitTest(point: point, context: context) != nil {
            return false
        }

        // MODIFIED: Use the passed-in event instead of the global NSApp.currentEvent.
        let isAdditive = event.modifierFlags.contains(.shift)

        // Store the selection state at the beginning of the drag.
        let initialGraphSelection = graph.selection

        self.state = .dragging(
            origin: point,
            isAdditive: isAdditive,
            initialGraphSelection: initialGraphSelection
        )
        return true
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(let origin, _, _) = state else { return }

        let marqueeRect = CGRect(origin: origin, size: .zero).union(CGRect(origin: point, size: .zero))

        controller.updateEnvironment {
            $0.marqueeRect = marqueeRect
        }

        let hitTester = ItemHitTester()
        let rawHits = hitTester.hitTestAll(in: marqueeRect, context: context)
        let resolved = Set(rawHits.map { context.selectionTarget(for: $0) })
        controller.setInteractionHighlight(elementIDs: resolved)
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(_, let isAdditive, let initialGraphSelection) = state else { return }

        let graph = context.graph
        let highlightedIDs = controller.interactionHighlightedElementIDs
        let finalGraphSelection = isAdditive
            ? initialGraphSelection.union(highlightedIDs)
            : Set(highlightedIDs)
        if graph.selection != finalGraphSelection {
            graph.selection = finalGraphSelection
        }
        self.state = .ready
        controller.updateEnvironment { $0.marqueeRect = nil }
        controller.setInteractionHighlight(elementIDs: [])
        return
    }
}
