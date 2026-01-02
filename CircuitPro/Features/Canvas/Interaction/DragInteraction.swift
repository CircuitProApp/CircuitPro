import AppKit
import SwiftUI

/// Unified drag interaction for all canvas elements.
///
/// Priority order:
/// 1. Transformable items (symbols, footprints via protocol)
/// 2. Connection elements (wires via ConnectionEngine)
/// 3. Special items (standalone text with anchor drag support)
final class DragInteraction: CanvasInteraction {
    // MARK: - State Types

    /// State for dragging Transformable items (protocol-based)
    private struct ItemDragState {
        struct Item {
            let id: UUID
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
        let originalTexts: [UUID: CanvasText]
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
        guard let itemsBinding = context.environment.items else { return false }
        let selection = context.graph.selection
        let selectedIDs = Set(selection.compactMap { $0.nodeID?.rawValue })
        guard !selectedIDs.isEmpty else { return false }

        let selectedItems = makeDraggableItems(
            selectedIDs: selectedIDs,
            items: itemsBinding.wrappedValue,
            itemsBinding: itemsBinding
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

        let resolvedHit = context.selectionTarget(for: graphHit)
        guard graph.selection.contains(resolvedHit) else { return false }

        let isWire: Bool
        switch graphHit {
        case .edge(let edgeID):
            isWire = graph.component(WireEdgeComponent.self, for: edgeID) != nil
        case .node:
            isWire = false
        }
        guard isWire else { return false }

        let selectedEdgeIDs = Set(graph.selection.compactMap { $0.edgeID?.rawValue })
        guard connectionEngine.beginDrag(selectedIDs: selectedEdgeIDs) else { return false }

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

        guard let itemsBinding = context.environment.items else { return false }
        let items = itemsBinding.wrappedValue

        guard case .node(let nodeID) = graphHit,
            itemText(for: nodeID.rawValue, in: items) != nil
        else {
            return false
        }

        let resolvedHit = context.selectionTarget(for: graphHit)
        guard graph.selection.contains(resolvedHit) else { return false }

        // Collect selected text components
        var originalTexts: [UUID: CanvasText] = [:]
        for elementID in graph.selection {
            guard case .node(let id) = elementID else { continue }
            if let text = itemText(for: id.rawValue, in: items) {
                originalTexts[id.rawValue] = text
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
        selectedIDs: Set<UUID>,
        items: [any CanvasItem],
        itemsBinding: Binding<[any CanvasItem]>
    ) -> [ItemDragState.Item] {
        var draggableItems: [ItemDragState.Item] = []

        for item in items where selectedIDs.contains(item.id) {
            guard let transformable = item as? (any CanvasItem & Transformable),
                let hitTestable = item as? (any CanvasItem & HitTestable)
            else { continue }

            let itemID = item.id
            let originalPosition = transformable.position
            let hitTest: (CGPoint, CGFloat) -> Bool = { point, tolerance in
                hitTestable.hitTest(point: point, tolerance: tolerance)
            }
            let updatePosition: (CGPoint) -> Void = { newPosition in
                self.updateTransformableItem(
                    id: itemID,
                    newPosition: newPosition,
                    itemsBinding: itemsBinding
                )
            }

            draggableItems.append(ItemDragState.Item(
                id: itemID,
                originalPosition: originalPosition,
                hitTest: hitTest,
                updatePosition: updatePosition
            ))
        }

        return draggableItems
    }

    private func handleTextDrag(to point: CGPoint, state: TextDragState, context: RenderContext) {
        let rawDelta = CGVector(dx: point.x - state.origin.x, dy: point.y - state.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }

        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)

        guard let itemsBinding = context.environment.items else { return }
        var items = itemsBinding.wrappedValue

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

            for index in items.indices where items[index].id == id {
                if items[index] is CanvasText {
                    items[index] = updated
                }
                break
            }
        }

        itemsBinding.wrappedValue = items
    }

    private func updateTransformableItem(
        id: UUID,
        newPosition: CGPoint,
        itemsBinding: Binding<[any CanvasItem]>
    ) {
        var items = itemsBinding.wrappedValue
        for index in items.indices where items[index].id == id {
            if var transformable = items[index] as? (any CanvasItem & Transformable) {
                transformable.position = newPosition
                items[index] = transformable
            }
            break
        }
        itemsBinding.wrappedValue = items
    }

    private func itemText(for id: UUID, in items: [any CanvasItem]) -> CanvasText? {
        for item in items where item.id == id {
            if let text = item as? CanvasText {
                return text
            }
        }
        return nil
    }
}
