//
//  RenderContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit
import SwiftUI

/// A snapshot of the canvas state, passed to each CK render layer during a drawing pass.
/// This struct bundles all the information a layer might need to render itself.
struct RenderContext {
    // MARK: - Core Framework Data
    let magnification: CGFloat
    let mouseLocation: CGPoint?
    let selectedTool: CanvasTool?
    let highlightedItemIDs: Set<UUID>
    let selectedItemIDs: Set<UUID>
    let highlightedLinkIDs: Set<UUID>
    let canvasBounds: CGRect
    let visibleRect: CGRect

    let layers: [any CanvasLayer]

    /// The ID of the currently active layer, if any.
    let activeLayerId: UUID?

    let snapProvider: any SnapProvider
    let items: [any CanvasItem]
    let itemsBinding: Binding<[any CanvasItem]>?
    let hitTargets: HitTargetRegistry
    let canvasDragHandlers: CanvasDragHandlerRegistry
    let hitTestDepth: Int
    let hitTestTransform: CGAffineTransform

    private let inputProcessors: [any InputProcessor]

    init(magnification: CGFloat, mouseLocation: CGPoint?, selectedTool: CanvasTool?, highlightedItemIDs: Set<UUID>, selectedItemIDs: Set<UUID>, highlightedLinkIDs: Set<UUID>, hostViewBounds: CGRect, visibleRect: CGRect, layers: [any CanvasLayer], activeLayerId: UUID?, snapProvider: any SnapProvider, items: [any CanvasItem], itemsBinding: Binding<[any CanvasItem]>?, inputProcessors: [any InputProcessor], hitTargets: HitTargetRegistry, canvasDragHandlers: CanvasDragHandlerRegistry, hitTestDepth: Int = 0, hitTestTransform: CGAffineTransform = .identity) {
        self.magnification = magnification
        self.mouseLocation = mouseLocation
        self.selectedTool = selectedTool
        self.highlightedItemIDs = highlightedItemIDs
        self.selectedItemIDs = selectedItemIDs
        self.highlightedLinkIDs = highlightedLinkIDs
        self.canvasBounds = hostViewBounds
        self.visibleRect = visibleRect
        self.layers = layers
        self.activeLayerId = activeLayerId
        self.snapProvider = snapProvider
        self.items = items
        self.itemsBinding = itemsBinding
        self.inputProcessors = inputProcessors
        self.hitTargets = hitTargets
        self.canvasDragHandlers = canvasDragHandlers
        self.hitTestDepth = hitTestDepth
        self.hitTestTransform = hitTestTransform
    }
}

extension RenderContext {
    func node<V: CKView>(_ view: V, index: Int = 0) -> CKRenderNode? {
        CKContextStorage.withViewScope(index: index) {
            CKStateRegistry.prepare(view)
            return view.makeNode(in: self)
        }
    }

    func node(_ view: any CKView, index: Int = 0) -> CKRenderNode? {
        CKContextStorage.withViewScope(index: index) {
            CKStateRegistry.prepare(view)
            return view.makeNode(in: self)
        }
    }
}

extension RenderContext {
    func withHitTestDepth(_ depth: Int) -> RenderContext {
        RenderContext(
            magnification: magnification,
            mouseLocation: mouseLocation,
            selectedTool: selectedTool,
            highlightedItemIDs: highlightedItemIDs,
            selectedItemIDs: selectedItemIDs,
            highlightedLinkIDs: highlightedLinkIDs,
            hostViewBounds: canvasBounds,
            visibleRect: visibleRect,
            layers: layers,
            activeLayerId: activeLayerId,
            snapProvider: snapProvider,
            items: items,
            itemsBinding: itemsBinding,
            inputProcessors: inputProcessors,
            hitTargets: hitTargets,
            canvasDragHandlers: canvasDragHandlers,
            hitTestDepth: depth,
            hitTestTransform: hitTestTransform
        )
    }

    func withHitTestTransform(_ transform: CGAffineTransform) -> RenderContext {
        RenderContext(
            magnification: magnification,
            mouseLocation: mouseLocation,
            selectedTool: selectedTool,
            highlightedItemIDs: highlightedItemIDs,
            selectedItemIDs: selectedItemIDs,
            highlightedLinkIDs: highlightedLinkIDs,
            hostViewBounds: canvasBounds,
            visibleRect: visibleRect,
            layers: layers,
            activeLayerId: activeLayerId,
            snapProvider: snapProvider,
            items: items,
            itemsBinding: itemsBinding,
            inputProcessors: inputProcessors,
            hitTargets: hitTargets,
            canvasDragHandlers: canvasDragHandlers,
            hitTestDepth: hitTestDepth,
            hitTestTransform: hitTestTransform.concatenating(transform)
        )
    }
}

extension RenderContext {
    func update<T: CanvasItem>(
        _ item: T,
        _ update: (inout T) -> Void
    ) {
        updateItem(item.id, as: T.self, update)
    }

    private func updateItem<T: CanvasItem>(
        _ id: UUID,
        as type: T.Type = T.self,
        _ update: (inout T) -> Void
    ) {
        guard let itemsBinding else { return }
        var items = itemsBinding.wrappedValue
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard var item = items[index] as? T else { return }
        update(&item)
        items[index] = item
        itemsBinding.wrappedValue = items
    }

    var connectionPoints: [any ConnectionPoint] {
        items.compactMap { $0 as? any ConnectionPoint }
    }

    var connectionLinks: [any ConnectionLink] {
        items.compactMap { $0 as? any ConnectionLink }
    }

    var connectionPointPositionsByID: [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        positions.reserveCapacity(connectionPoints.count)
        for point in connectionPoints {
            positions[point.id] = point.position
        }
        return positions
    }
}
