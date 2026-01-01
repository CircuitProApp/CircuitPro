import AppKit

/// Unified drag interaction for all canvas elements.
///
/// Priority order:
/// 1. Transformable items (symbols, footprints via protocol)
/// 2. Connection elements (wires, traces via ConnectionEngine)
/// 3. Special items (standalone text with anchor drag support)
final class DragInteraction: CanvasInteraction {

    // MARK: - State Types

    /// State for dragging Transformable items (protocol-based)
    private struct ItemDragState {
        struct Item {
            let id: NodeID
            let originalPosition: CGPoint
            let hitTest: (CGPoint, CGFloat) -> Bool
            let updatePosition: (CGPoint) -> Void
        }

        let origin: CGPoint
        let items: [Item]
        let connectionEngine: (any ConnectionEngine)?
    }

    /// State for dragging connection elements only (wires/traces)
    private struct ConnectionDragState {
        let origin: CGPoint
        let connectionEngine: any ConnectionEngine
    }

    /// State for dragging text elements (with anchor support)
    private struct TextDragState {
        let origin: CGPoint
        let originalTexts: [NodeID: CanvasText]
        let isAnchorDrag: Bool
    }

    // MARK: - Properties

    private var itemState: ItemDragState?
    private var connectionState: ConnectionDragState?
    private var textState: TextDragState?
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0

    var wantsRawInput: Bool { true }

    // MARK: - Mouse Down

    func mouseDown(
        with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController
    ) -> Bool {
        resetState()
        guard controller.selectedTool is CursorTool else { return false }

        // Try each drag type in priority order
        if tryStartItemDrag(at: point, context: context) {
            return true
        }

        if tryStartConnectionDrag(at: point, context: context) {
            return true
        }

        if tryStartTextDrag(at: point, event: event, context: context) {
            return true
        }

        return false
    }

    // MARK: - Mouse Dragged

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        if let state = itemState {
            handleItemDrag(to: point, state: state, context: context)
            return
        }

        if let state = connectionState {
            handleConnectionDrag(to: point, state: state, context: context)
            return
        }

        if let state = textState {
            handleTextDrag(to: point, state: state, context: context)
            return
        }
    }

    // MARK: - Mouse Up

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        itemState?.connectionEngine?.endDrag()
        connectionState?.connectionEngine.endDrag()
        resetState()
    }

    // MARK: - Private: Reset

    private func resetState() {
        itemState = nil
        connectionState = nil
        textState = nil
        didMove = false
    }

    // MARK: - Private: Item Drag (Transformable Protocol)

    private func tryStartItemDrag(at point: CGPoint, context: RenderContext) -> Bool {
        let selection = context.graph.selection
        guard !selection.isEmpty else { return false }

        let graph = context.graph
        let selectedIDs = Set(selection.map { $0.rawValue })
        let selectedItems = makeDraggableItems(
            in: graph,
            selectedIDs: selectedIDs
        )

        guard !selectedItems.isEmpty else { return false }

        // Check if we hit one of the selected items
        var hitSelected = false
        for item in selectedItems {
            if item.hitTest(point, 5.0) {
                hitSelected = true
                break
            }
        }
        guard hitSelected else { return false }

        // Start connection engine drag if applicable
        var activeConnectionEngine: (any ConnectionEngine)?
        if let connectionEngine = context.environment.connectionEngine {
            if connectionEngine.beginDrag(selectedIDs: selectedIDs) {
                activeConnectionEngine = connectionEngine
            }
        }

        self.itemState = ItemDragState(
            origin: point,
            items: selectedItems,
            connectionEngine: activeConnectionEngine
        )
        return true
    }

    private func handleItemDrag(to point: CGPoint, state: ItemDragState, context: RenderContext) {
        let rawDelta = CGVector(dx: point.x - state.origin.x, dy: point.y - state.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }

        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)

        // Set new position on each item from its original position
        for item in state.items {
            let newPosition = CGPoint(
                x: item.originalPosition.x + deltaPoint.x,
                y: item.originalPosition.y + deltaPoint.y
            )
            item.updatePosition(newPosition)
        }

        // Update connection engine
        state.connectionEngine?.updateDrag(by: deltaPoint)
    }

    // MARK: - Private: Connection Drag (Wires/Traces Only)

    private func tryStartConnectionDrag(at point: CGPoint, context: RenderContext) -> Bool {
        guard let connectionEngine = context.environment.connectionEngine else { return false }

        let graph = context.graph
        guard let graphHit = GraphHitTester().hitTest(point: point, context: context) else {
            return false
        }

        let resolvedHit = graph.selectionTarget(for: graphHit)
        guard graph.selection.contains(resolvedHit) else { return false }

        // Check if hit is a wire/trace element
        let isWire =
            graph.component(WireEdgeComponent.self, for: graphHit) != nil
            || graph.component(WireVertexComponent.self, for: graphHit) != nil
        let isTrace =
            graph.component(TraceEdgeComponent.self, for: graphHit) != nil
            || graph.component(TraceVertexComponent.self, for: graphHit) != nil

        guard isWire || isTrace else { return false }

        let selectedIDs = Set(graph.selection.map { $0.rawValue })
        guard connectionEngine.beginDrag(selectedIDs: selectedIDs) else { return false }

        self.connectionState = ConnectionDragState(
            origin: point, connectionEngine: connectionEngine)
        return true
    }

    private func handleConnectionDrag(
        to point: CGPoint, state: ConnectionDragState, context: RenderContext
    ) {
        let rawDelta = CGVector(dx: point.x - state.origin.x, dy: point.y - state.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }

        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)
        state.connectionEngine.updateDrag(by: deltaPoint)
    }

    // MARK: - Private: Text Drag (Standalone Text with Anchor Support)

    private func tryStartTextDrag(
        at point: CGPoint, event: NSEvent, context: RenderContext
    ) -> Bool {
        let graph = context.graph
        guard let graphHit = GraphHitTester().hitTest(point: point, context: context) else {
            return false
        }

        guard graph.component(CanvasText.self, for: graphHit) != nil else {
            return false
        }

        let resolvedHit = graph.selectionTarget(for: graphHit)
        guard graph.selection.contains(resolvedHit) else { return false }

        // Collect selected text components
        var originalTexts: [NodeID: CanvasText] = [:]
        for id in graph.selection {
            if let text = graph.component(CanvasText.self, for: id) {
                originalTexts[id] = text
            }
        }

        guard !originalTexts.isEmpty else { return false }

        let isAnchorDrag = event.modifierFlags.contains(.control)
        self.textState = TextDragState(
            origin: point,
            originalTexts: originalTexts,
            isAnchorDrag: isAnchorDrag
        )
        return true
    }

    private func makeDraggableItems(
        in graph: CanvasGraph,
        selectedIDs: Set<UUID>
    ) -> [ItemDragState.Item] {
        var items: [ItemDragState.Item] = []

        for id in graph.selection {
            guard selectedIDs.contains(id.rawValue) else { continue }

            if let item = makeItem(from: graph.component(ComponentInstance.self, for: id), id: id, graph: graph) {
                items.append(item)
                continue
            }
            if let item = makeItem(from: graph.component(CanvasFootprint.self, for: id), id: id, graph: graph) {
                items.append(item)
                continue
            }
            if let item = makeItem(from: graph.component(CanvasText.self, for: id), id: id, graph: graph) {
                items.append(item)
                continue
            }
            if let item = makeItem(from: graph.component(CanvasPrimitiveElement.self, for: id), id: id, graph: graph) {
                items.append(item)
                continue
            }
            if let item = makeItem(from: graph.component(CanvasPin.self, for: id), id: id, graph: graph) {
                items.append(item)
                continue
            }
            if let item = makeItem(from: graph.component(AnyCanvasPrimitive.self, for: id), id: id, graph: graph) {
                items.append(item)
            }
        }

        return items
    }

    private func makeItem<T: Transformable & HitTestable>(
        from component: T?,
        id: NodeID,
        graph: CanvasGraph
    ) -> ItemDragState.Item? {
        guard let component else { return nil }

        return ItemDragState.Item(
            id: id,
            originalPosition: component.position,
            hitTest: { point, tolerance in
                component.hitTest(point: point, tolerance: tolerance)
            },
            updatePosition: { newPosition in
                var updated = component
                updated.position = newPosition
                graph.setComponent(updated, for: id)
            }
        )
    }

    private func handleTextDrag(to point: CGPoint, state: TextDragState, context: RenderContext) {
        let rawDelta = CGVector(dx: point.x - state.origin.x, dy: point.y - state.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }

        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)
        let graph = context.graph

        for (id, original) in state.originalTexts {
            var updated = original
            updated.worldPosition = original.worldPosition + deltaPoint
            let inverseOwner = original.ownerTransform.inverted()
            updated.resolvedText.relativePosition = updated.worldPosition.applying(inverseOwner)

            if state.isAnchorDrag {
                updated.worldAnchorPosition = original.worldAnchorPosition + deltaPoint
                updated.resolvedText.anchorPosition = updated.worldAnchorPosition.applying(
                    inverseOwner)
            }

            graph.setComponent(updated, for: id)
        }
    }
}
