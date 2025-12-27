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
        case dragging(origin: CGPoint, isAdditive: Bool, initialSelection: [BaseNode], initialGraphSelection: Set<NodeID>)
    }

    private var state: State = .ready

    var wantsRawInput: Bool { true }

    // MODIFIED: Updated method signature to accept NSEvent.
    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedTool is CursorTool else { return false }

        let tolerance = 5.0 / context.magnification
        // This interaction starts only if the click was on an empty area.
        if context.graph != nil, GraphHitTester().hitTest(point: point, context: context) != nil {
            return false
        }
        if context.environment.interactionMode != .graphOnly,
           context.sceneRoot.hitTest(point, tolerance: tolerance) != nil {
            return false
        }

        // MODIFIED: Use the passed-in event instead of the global NSApp.currentEvent.
        let isAdditive = event.modifierFlags.contains(.shift)

        // Store the selection state at the beginning of the drag.
        let initialSelection = controller.selectedNodes
        let initialGraphSelection = context.graph?.selection ?? []

        self.state = .dragging(
            origin: point,
            isAdditive: isAdditive,
            initialSelection: initialSelection,
            initialGraphSelection: initialGraphSelection
        )
        return true
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(let origin, _, _, _) = state else { return }

        let marqueeRect = CGRect(origin: origin, size: .zero).union(CGRect(origin: point, size: .zero))

        controller.updateEnvironment {
            $0.marqueeRect = marqueeRect
        }

        let intersectingNodes: [BaseNode]
        let graphHitIDs: Set<UUID>
        if context.graph != nil {
            let hitTester = GraphHitTester()
            graphHitIDs = Set(hitTester.hitTestAll(in: marqueeRect, context: context).map { $0.rawValue })
            if context.environment.interactionMode == .graphOnly {
                intersectingNodes = []
            } else {
                intersectingNodes = context.sceneRoot.nodes(intersecting: marqueeRect)
            }
        } else {
            graphHitIDs = []
            // Get all nodes that intersect the marquee rectangle.
            intersectingNodes = context.sceneRoot.nodes(intersecting: marqueeRect)
        }

        // --- Smart Highlighting Logic ---
        // This logic unifies the selection of a symbol and its text. If both are
        // under the marquee, we only highlight the symbol.

        var finalHighlightableNodes = Set(intersectingNodes)

        // Find all the text nodes and symbol nodes within the current marquee area.
        let textNodesInMarquee = finalHighlightableNodes.compactMap { $0 as? AnchoredTextNode }
        let symbolsInMarquee = finalHighlightableNodes.compactMap { $0 as? SymbolNode }

        var suppressedTextIDs = Set<UUID>()

        // If a text node's parent symbol is also in the marquee, remove the text node
        // from the highlight set to create a single, unified highlight on the symbol.
        for textNode in textNodesInMarquee {
            if let parentSymbol = textNode.parent as? SymbolNode, symbolsInMarquee.contains(parentSymbol) {
                finalHighlightableNodes.remove(textNode)
                suppressedTextIDs.insert(textNode.id)
            }
        }

        var highlightedIDs = Set(finalHighlightableNodes.map { $0.id })
        highlightedIDs.formUnion(graphHitIDs.subtracting(suppressedTextIDs))
        controller.setInteractionHighlight(nodeIDs: highlightedIDs)
    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(_, let isAdditive, let initialSelection, let initialGraphSelection) = state else { return }

        if context.environment.interactionMode == .graphOnly {
            if let graph = context.graph {
                let highlightedIDs = controller.interactionHighlightedNodeIDs
                let graphHitIDs = highlightedIDs.filter { graph.hasAnyComponent(for: NodeID($0)) }
                let finalGraphSelection = isAdditive
                    ? initialGraphSelection.union(graphHitIDs.map(NodeID.init))
                    : Set(graphHitIDs.map(NodeID.init))
                if graph.selection != finalGraphSelection {
                    graph.selection = finalGraphSelection
                }
            }
            controller.setSelection(to: [])
            self.state = .ready
            controller.updateEnvironment { $0.marqueeRect = nil }
            controller.setInteractionHighlight(nodeIDs: [])
            return
        }

        // 1. Get the nodes that were highlighted by the marquee drag.
        let highlightedNodes = controller.interactionHighlightedNodeIDs.compactMap { id in
            controller.findNode(with: id, in: context.sceneRoot)
        }

        // 2. Calculate the final selection.
        if let graph = context.graph {
            let highlightedIDs = controller.interactionHighlightedNodeIDs
            let graphHitIDs = highlightedIDs.filter { graph.hasAnyComponent(for: NodeID($0)) }
            let finalGraphSelection = isAdditive
                ? initialGraphSelection.union(graphHitIDs.map(NodeID.init))
                : Set(graphHitIDs.map(NodeID.init))
            if graph.selection != finalGraphSelection {
                graph.selection = finalGraphSelection
            }
        }

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
