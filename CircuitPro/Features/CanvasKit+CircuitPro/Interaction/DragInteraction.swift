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

    private enum Axis {
        case horizontal
        case vertical
        case diagonal
    }

    // MARK: - Properties

    private var itemState: ItemDragState?
    private var textState: TextDragState?
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0
    private var liveLinkAxis: [UUID: Axis] = [:]

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
        if itemState != nil, didMove {
            applyConnectionNormalization(context: context)
        }
        resetState()
    }

    // MARK: - Private: Reset

    private func resetState() {
        itemState = nil
        textState = nil
        didMove = false
        liveLinkAxis = [:]
    }

    private func applyConnectionNormalization(context: RenderContext) {
        guard let itemsBinding = context.environment.items,
              let engine = context.connectionEngine
        else { return }

        var items = itemsBinding.wrappedValue
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let links = items.compactMap { $0 as? any ConnectionLink }
        let normalizationContext = ConnectionNormalizationContext(
            magnification: context.magnification,
            snapPoint: { point in
                context.snapProvider.snap(point: point, context: context)
            }
        )
        let delta = engine.normalize(points: points, links: links, context: normalizationContext)
        if delta.isEmpty {
            return
        }

        if !delta.removedLinkIDs.isEmpty || !delta.removedPointIDs.isEmpty {
            items.removeAll { item in
                delta.removedLinkIDs.contains(item.id)
                    || delta.removedPointIDs.contains(item.id)
            }
        }

        if !delta.updatedPoints.isEmpty
            || !delta.addedPoints.isEmpty
            || !delta.updatedLinks.isEmpty
            || !delta.addedLinks.isEmpty {
            var indexByID: [UUID: Int] = [:]
            indexByID.reserveCapacity(items.count)
            for (index, item) in items.enumerated() {
                indexByID[item.id] = index
            }

            func upsert(_ item: any CanvasItem) {
                if let index = indexByID[item.id] {
                    items[index] = item
                } else {
                    items.append(item)
                    indexByID[item.id] = items.count - 1
                }
            }

            for point in delta.updatedPoints {
                upsert(point)
            }
            for point in delta.addedPoints {
                upsert(point)
            }
            for link in delta.updatedLinks {
                upsert(link)
            }
            for link in delta.addedLinks {
                upsert(link)
            }
        }

        itemsBinding.wrappedValue = items
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
        seedLiveLinkAxis(context: context)
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

        if context.connectionEngine != nil {
            applyLiveWireConstraints(
                movedItemIDs: Set(state.items.map { $0.id }),
                context: context
            )
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

    private func symbolPinPointIDs(in points: [any ConnectionPoint]) -> [UUID: [UUID]] {
        var map: [UUID: [UUID]] = [:]
        for point in points {
            guard let pinPoint = point as? SymbolPinPoint else { continue }
            map[pinPoint.symbolID, default: []].append(pinPoint.id)
        }
        return map
    }

    private func applyLiveWireConstraints(
        movedItemIDs: Set<UUID>,
        context: RenderContext
    ) {
        guard let itemsBinding = context.environment.items else { return }
        var items = itemsBinding.wrappedValue
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let links = items.compactMap { $0 as? any ConnectionLink }
        guard !points.isEmpty, !links.isEmpty else { return }

        let movedSymbolIDs = items.compactMap { item -> UUID? in
            guard let component = item as? ComponentInstance,
                  movedItemIDs.contains(component.id)
            else { return nil }
            return component.symbolInstance.id
        }

        let symbolPinIDs = symbolPinPointIDs(in: points)
        let movedPinIDs = movedSymbolIDs.flatMap { symbolPinIDs[$0] ?? [] }
        guard !movedPinIDs.isEmpty else { return }

        let tolerance = 6.0 / max(context.magnification, 0.001)
        var positions = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        let linkAxis = linkAxisMap(for: links, positions: positions, tolerance: tolerance)
        let adjacency = linkAdjacency(for: links)
        let linkEndpoints = linkEndpointMap(for: links)
        var fixedPointIDs = fixedPoints(in: points)
        fixedPointIDs.subtract(movedPinIDs)

        applyOrthogonalConstraints(
            movedIDs: movedPinIDs,
            positions: &positions,
            originalPositions: positions,
            adjacency: adjacency,
            linkAxis: linkAxis,
            linkEndpoints: linkEndpoints,
            fixedPointIDs: fixedPointIDs,
            anchoredIDs: Set(movedPinIDs)
        )

        for index in items.indices {
            guard let vertex = items[index] as? WireVertex,
                  let updated = positions[vertex.id],
                  vertex.position != updated
            else { continue }
            var copy = vertex
            copy.position = updated
            items[index] = copy
        }

        let preferHorizontalFirst = (context.connectionEngine as? WireEngine)?.preferHorizontalFirst ?? true
        applySplitDiagonalNormalization(
            to: &items,
            context: context,
            preferHorizontalFirst: preferHorizontalFirst
        )

        itemsBinding.wrappedValue = items
    }

    private func seedLiveLinkAxis(context: RenderContext) {
        let points = context.connectionPoints
        let links = context.connectionLinks
        guard !points.isEmpty, !links.isEmpty else {
            liveLinkAxis = [:]
            return
        }

        let tolerance = 6.0 / max(context.magnification, 0.001)
        let positions = context.connectionPointPositionsByID
        var map: [UUID: Axis] = [:]
        map.reserveCapacity(links.count)

        for link in links {
            guard let start = positions[link.startID],
                  let end = positions[link.endID]
            else { continue }
            let dx = abs(start.x - end.x)
            let dy = abs(start.y - end.y)
            if dx <= tolerance {
                map[link.id] = .vertical
            } else if dy <= tolerance {
                map[link.id] = .horizontal
            } else {
                map[link.id] = .diagonal
            }
        }

        liveLinkAxis = map
    }

    private func linkAxisMap(
        for links: [any ConnectionLink],
        positions: [UUID: CGPoint],
        tolerance: CGFloat
    ) -> [UUID: Axis] {
        var map: [UUID: Axis] = [:]
        map.reserveCapacity(links.count)
        var currentIDs = Set<UUID>()
        currentIDs.reserveCapacity(links.count)

        for link in links {
            currentIDs.insert(link.id)
            if let axis = liveLinkAxis[link.id] {
                map[link.id] = axis
                continue
            }

            guard let start = positions[link.startID],
                  let end = positions[link.endID]
            else { continue }
            let dx = abs(start.x - end.x)
            let dy = abs(start.y - end.y)
            let axis: Axis
            if dx <= tolerance {
                axis = .vertical
            } else if dy <= tolerance {
                axis = .horizontal
            } else {
                axis = .diagonal
            }
            liveLinkAxis[link.id] = axis
            map[link.id] = axis
        }

        liveLinkAxis = liveLinkAxis.filter { currentIDs.contains($0.key) }
        return map
    }

    private func linkAdjacency(for links: [any ConnectionLink]) -> [UUID: [UUID]] {
        var adjacency: [UUID: [UUID]] = [:]
        for link in links {
            adjacency[link.startID, default: []].append(link.id)
            adjacency[link.endID, default: []].append(link.id)
        }
        return adjacency
    }

    private func linkEndpointMap(for links: [any ConnectionLink]) -> [UUID: (UUID, UUID)] {
        var map: [UUID: (UUID, UUID)] = [:]
        map.reserveCapacity(links.count)
        for link in links {
            map[link.id] = (link.startID, link.endID)
        }
        return map
    }

    private func fixedPoints(in points: [any ConnectionPoint]) -> Set<UUID> {
        var fixed = Set<UUID>()
        fixed.reserveCapacity(points.count)
        for point in points where !(point is WireVertex) {
            fixed.insert(point.id)
        }
        return fixed
    }

    private func applyOrthogonalConstraints(
        movedIDs: [UUID],
        positions: inout [UUID: CGPoint],
        originalPositions: [UUID: CGPoint],
        adjacency: [UUID: [UUID]],
        linkAxis: [UUID: Axis],
        linkEndpoints: [UUID: (UUID, UUID)],
        fixedPointIDs: Set<UUID>,
        anchoredIDs: Set<UUID>
    ) {
        var queue = movedIDs
        var queued = Set(movedIDs)

        func isFixed(_ id: UUID) -> Bool {
            fixedPointIDs.contains(id)
        }

        while let currentID = queue.first {
            queue.removeFirst()
            queued.remove(currentID)

            guard let currentPos = positions[currentID],
                  let currentOrig = originalPositions[currentID]
            else { continue }

            for linkID in adjacency[currentID] ?? [] {
                guard let axis = linkAxis[linkID],
                      let endpoints = linkEndpoints[linkID]
                else { continue }

                let (aID, bID) = endpoints
                let otherID = (aID == currentID) ? bID : aID
                guard otherID != currentID else { continue }

                guard let otherOrig = originalPositions[otherID] else { continue }
                var otherPos = positions[otherID] ?? otherOrig

                switch axis {
                case .horizontal:
                    otherPos.y = currentPos.y
                case .vertical:
                    otherPos.x = currentPos.x
                case .diagonal:
                    continue
                }

                if isFixed(otherID) {
                    if !anchoredIDs.contains(currentID) {
                        positions[currentID] = align(current: currentPos, fixed: otherOrig, axis: axis)
                    }
                } else if positions[otherID] != otherPos {
                    positions[otherID] = otherPos
                    if !queued.contains(otherID) {
                        queue.append(otherID)
                        queued.insert(otherID)
                    }
                }
            }
        }
    }

    private func align(current: CGPoint, fixed: CGPoint, axis: Axis) -> CGPoint {
        switch axis {
        case .horizontal:
            return CGPoint(x: current.x, y: fixed.y)
        case .vertical:
            return CGPoint(x: fixed.x, y: current.y)
        case .diagonal:
            return current
        }
    }

    private func applySplitDiagonalNormalization(
        to items: inout [any CanvasItem],
        context: RenderContext,
        preferHorizontalFirst: Bool
    ) {
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let links = items.compactMap { $0 as? any ConnectionLink }
        guard !points.isEmpty, !links.isEmpty else { return }

        let epsilon = max(0.5 / max(context.magnification, 0.0001), 0.0001)
        var pointsByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        let pointsByObject = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
        let originalLinksByID = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })
        let preferredIDs = Set(originalLinksByID.keys)

        var state = NormalizationState(
            pointsByID: pointsByID,
            pointsByObject: pointsByObject,
            links: links.map { WireSegment(id: $0.id, startID: $0.startID, endID: $0.endID) },
            addedPoints: [],
            removedPointIDs: [],
            removedLinkIDs: [],
            epsilon: epsilon,
            preferredIDs: preferredIDs
        )

        let rule = SplitDiagonalLinksRule(preferHorizontalFirst: preferHorizontalFirst)
        rule.apply(to: &state)

        pointsByID = state.pointsByID
        let finalIDs = Set(state.links.map { $0.id })
        var removedLinkIDs = state.removedLinkIDs
        removedLinkIDs.formUnion(Set(originalLinksByID.keys).subtracting(finalIDs))

        var updatedLinks: [any CanvasItem & ConnectionLink] = []
        var addedLinksOut: [any CanvasItem & ConnectionLink] = []
        for link in state.links {
            if let original = originalLinksByID[link.id] {
                if original.startID != link.startID || original.endID != link.endID {
                    updatedLinks.append(link)
                }
            } else {
                addedLinksOut.append(link)
            }
        }

        let removedPointIDs = state.removedPointIDs
        let addedPointsOut = state.addedPoints.filter { !removedPointIDs.contains($0.id) }
        if removedPointIDs.isEmpty
            && removedLinkIDs.isEmpty
            && updatedLinks.isEmpty
            && addedLinksOut.isEmpty
            && addedPointsOut.isEmpty {
            return
        }

        if !removedLinkIDs.isEmpty || !removedPointIDs.isEmpty {
            items.removeAll { item in
                removedLinkIDs.contains(item.id)
                    || removedPointIDs.contains(item.id)
            }
        }

        if !updatedLinks.isEmpty
            || !addedLinksOut.isEmpty
            || !addedPointsOut.isEmpty {
            var indexByID: [UUID: Int] = [:]
            indexByID.reserveCapacity(items.count)
            for (index, item) in items.enumerated() {
                indexByID[item.id] = index
            }

            func upsert(_ item: any CanvasItem) {
                if let index = indexByID[item.id] {
                    items[index] = item
                } else {
                    items.append(item)
                    indexByID[item.id] = items.count - 1
                }
            }

            for point in addedPointsOut {
                upsert(point)
            }
            for link in updatedLinks {
                upsert(link)
            }
            for link in addedLinksOut {
                upsert(link)
            }
        }
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
