import AppKit
import SwiftUI

/// Unified drag interaction for all canvas elements.
///
/// Priority order:
/// 1. Transformable items (symbols, footprints via protocol)
/// 2. Connection elements (wires)
/// 3. Special items (standalone text with anchor drag support)
final class DragInteraction: CanvasInteraction {
    // MARK: - State Types

    /// State for dragging Transformable items (protocol-based)
    private struct ItemDragState {
        struct Item {
            let id: UUID
            let originalPosition: CGPoint
            let updatePosition: (CGPoint) -> Void
        }

        let origin: CGPoint
        let items: [Item]
    }

    /// State for dragging text elements (with anchor support)
    private struct TextDragState {
        let origin: CGPoint
        let definitionTexts: [UUID: CircuitText.Definition]
        let componentTexts: [UUID: ComponentTextSelection]
        let isAnchorDrag: Bool
    }

    private struct ComponentTextSelection {
        let owner: ComponentInstance
        let target: TextTarget
        let original: CircuitText.Resolved
        let ownerTransform: CGAffineTransform
    }

    // MARK: - Properties

    private var itemState: ItemDragState?
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
        if tryStartItemDrag(at: point, context: context, controller: controller) {
            return true
        }

        if tryStartTextDrag(at: point, event: event, context: context, controller: controller) {
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

        if let state = textState {
            handleTextDrag(to: point, state: state, context: context)
            return
        }
    }

    // MARK: - Mouse Up

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        resetState()
    }

    // MARK: - Private: Reset

    private func resetState() {
        itemState = nil
        textState = nil
        didMove = false
    }

    // MARK: - Private: Item Drag (Transformable Protocol)

    private func tryStartItemDrag(
        at point: CGPoint,
        context: RenderContext,
        controller: CanvasController
    ) -> Bool {
        guard let hit = CanvasHitTester().hitTest(point: point, context: context) else { return false }
        var selectedIDs = context.selectedItemIDs
        if !selectedIDs.contains(hit) {
            controller.updateSelection([hit])
            selectedIDs = [hit]
        }

        guard let itemsBinding = context.environment.items else { return false }
        let selectedItems = makeDraggableItems(
            selectedIDs: selectedIDs,
            items: itemsBinding.wrappedValue,
            itemsBinding: itemsBinding
        )

        guard !selectedItems.isEmpty else { return false }

        self.itemState = ItemDragState(
            origin: point,
            items: selectedItems
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

    }

    // MARK: - Private: Text Drag (Standalone Text with Anchor Support)

    private func tryStartTextDrag(
        at point: CGPoint,
        event: NSEvent,
        context: RenderContext,
        controller: CanvasController
    ) -> Bool {
        guard let graphHit = CanvasHitTester().hitTest(point: point, context: context) else {
            return false
        }

        guard let itemsBinding = context.environment.items else { return false }
        let items = itemsBinding.wrappedValue

        var selectedIDs = context.selectedItemIDs
        if !selectedIDs.contains(graphHit) {
            controller.updateSelection([graphHit])
            selectedIDs = [graphHit]
        }

        let selections = collectTextSelections(
            selectedIDs: selectedIDs,
            items: items,
            context: context
        )
        guard selections.definitionTexts[graphHit] != nil
                || selections.componentTexts[graphHit] != nil
        else { return false }

        guard !(selections.definitionTexts.isEmpty && selections.componentTexts.isEmpty) else {
            return false
        }

        let isAnchorDrag = event.modifierFlags.contains(.control)
        self.textState = TextDragState(
            origin: point,
            definitionTexts: selections.definitionTexts,
            componentTexts: selections.componentTexts,
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
            guard let transformable = item as? (any CanvasItem & Transformable) else { continue }

            let itemID = item.id
            let originalPosition = transformable.position
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

        if let itemsBinding = context.environment.items {
            var items = itemsBinding.wrappedValue

            for (id, original) in state.definitionTexts {
                var updated = original
                let worldPosition = CanvasTextGeometry.worldPosition(
                    relativePosition: original.relativePosition,
                    ownerTransform: .identity
                ) + deltaPoint
                updated.relativePosition = worldPosition

                if state.isAnchorDrag {
                    let anchorPosition = CanvasTextGeometry.worldAnchorPosition(
                        anchorPosition: original.anchorPosition,
                        ownerTransform: .identity
                    ) + deltaPoint
                    updated.anchorPosition = anchorPosition
                }

                for index in items.indices where items[index].id == id {
                    if items[index] is CircuitText.Definition {
                        items[index] = updated
                    }
                    break
                }
            }

            for (_, selection) in state.componentTexts {
                let inverseOwner = selection.ownerTransform.inverted()
                let original = selection.original
                let worldPosition = CanvasTextGeometry.worldPosition(
                    relativePosition: original.relativePosition,
                    ownerTransform: selection.ownerTransform
                ) + deltaPoint
                var updated = original
                updated.relativePosition = worldPosition.applying(inverseOwner)

                if state.isAnchorDrag {
                    let anchorWorld = CanvasTextGeometry.worldAnchorPosition(
                        anchorPosition: original.anchorPosition,
                        ownerTransform: selection.ownerTransform
                    ) + deltaPoint
                    updated.anchorPosition = anchorWorld.applying(inverseOwner)
                }
                selection.owner.apply(updated, for: selection.target)
            }

            itemsBinding.wrappedValue = items
        }
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

    private func collectTextSelections(
        selectedIDs: Set<UUID>,
        items: [any CanvasItem],
        context: RenderContext
    ) -> (definitionTexts: [UUID: CircuitText.Definition], componentTexts: [UUID: ComponentTextSelection]) {
        var definitionTexts: [UUID: CircuitText.Definition] = [:]
        var componentTexts: [UUID: ComponentTextSelection] = [:]

        for item in items {
            if let text = item as? CircuitText.Definition, selectedIDs.contains(text.id) {
                definitionTexts[text.id] = text
                continue
            }

            guard let component = item as? ComponentInstance else { continue }
            let target = context.environment.textTarget
            guard let ownerInfo = componentTextOwner(component, target: target) else { continue }

            for resolved in ownerInfo.resolvedItems {
                let textID = CanvasTextID.makeID(
                    for: resolved.source,
                    ownerID: component.id,
                    fallback: resolved.id
                )
                guard selectedIDs.contains(textID) else { continue }
                let selection = ComponentTextSelection(
                    owner: component,
                    target: target,
                    original: resolved,
                    ownerTransform: ownerInfo.transform
                )
                componentTexts[textID] = selection
            }
        }

        return (definitionTexts, componentTexts)
    }

    private func componentTextOwner(
        _ component: ComponentInstance,
        target: TextTarget
    ) -> (resolvedItems: [CircuitText.Resolved], transform: CGAffineTransform)? {
        switch target {
        case .symbol:
            let instance = component.symbolInstance
            let transform = CGAffineTransform(translationX: instance.position.x, y: instance.position.y)
                .rotated(by: instance.rotation)
            return (instance.resolvedItems, transform)
        case .footprint:
            guard let instance = component.footprintInstance else { return nil }
            let transform = CGAffineTransform(translationX: instance.position.x, y: instance.position.y)
                .rotated(by: instance.rotation)
            return (instance.resolvedItems, transform)
        }
    }
}
