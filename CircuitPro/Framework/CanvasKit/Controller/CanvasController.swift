//
//  CanvasController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit
import SwiftUI

final class CanvasController {

    // MARK: - Core Data Model

    private var interactionHighlightedItemIDs: Set<UUID> = []
    private var interactionHighlightedLinkIDs: Set<UUID> = []
    var highlightedItemIDs: Set<UUID> { interactionHighlightedItemIDs }
    var highlightedLinkIDs: Set<UUID> { interactionHighlightedLinkIDs }
    private var selectedItemIDs: Set<UUID> = []
    var onSelectionChange: ((Set<UUID>) -> Void)?

    // MARK: - View Reference

    /// A weak reference to the AppKit view this controller manages.
    /// Used to trigger imperative redraws for transient visual state changes.
    weak var view: CanvasHostView?

    // MARK: - Universal View State

    var magnification: CGFloat {
        get { environment.magnification }
        set { environment.magnification = newValue }
    }

    var mouseLocation: CGPoint? {
        get { environment.mouseLocation }
        set {
            guard environment.mouseLocation != newValue else { return }
            environment.mouseLocation = newValue
            view?.requestLayerUpdate() // Redraw for layers like Crosshairs.
        }
    }

    var visibleRect: CGRect {
        get { environment.visibleRect }
        set { environment.visibleRect = newValue }
    }

    var selectedTool: CanvasTool?
    var environment: CanvasEnvironmentValues = .init()
    var layers: [any CanvasLayer]?
    var activeLayerId: UUID?
    var items: [any CanvasItem] = []
    var itemsBinding: Binding<[any CanvasItem]>?

    // MARK: - Pluggable Pipelines

    let renderViews: [any CKView]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider
    let renderer: CKRenderer
    let canvasDragHandlers = CanvasDragHandlerRegistry()

    // MARK: - Callbacks to Owner

    var onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?

    // MARK: - Init

    init(
        renderViews: [any CKView],
        inputProcessors: [any InputProcessor],
        snapProvider: any SnapProvider,
        renderer: CKRenderer = DefaultCKRenderer()
    ) {
        self.renderViews = renderViews
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.renderer = renderer
    }

    // MARK: - State Syncing API

    /// The primary entry point for SwiftUI to push state updates *into* the controller.
    func sync(
        tool: CanvasTool?,
        magnification: CGFloat,
        environment: CanvasEnvironmentValues,
        layers: [any CanvasLayer]?,
        activeLayerId: UUID?,
        selectedItemIDs: Set<UUID>,
        items: [any CanvasItem],
        itemsBinding: Binding<[any CanvasItem]>?
    ) {
        // --- Other State ---
        if self.selectedTool?.id != tool?.id { self.selectedTool = tool }
        self.magnification = magnification
        self.environment.merge(environment)
        self.layers = layers
        self.activeLayerId = activeLayerId
        updateSelection(selectedItemIDs, notify: false)
        self.items = items
        self.itemsBinding = itemsBinding
    }

    /// Creates a definitive, non-optional RenderContext for a given drawing pass.
    func currentContext(for hostViewBounds: CGRect, visibleRect: CGRect) -> RenderContext {
        environment.visibleRect = visibleRect
        var allHighlightedIDs = interactionHighlightedItemIDs
        allHighlightedIDs.formUnion(selectedItemIDs)
        let resolvedItems = itemsBinding?.wrappedValue ?? items
        return RenderContext(
            magnification: self.magnification,
            mouseLocation: self.mouseLocation,
            selectedTool: self.selectedTool,
            highlightedItemIDs: allHighlightedIDs,
            selectedItemIDs: selectedItemIDs,
            highlightedLinkIDs: interactionHighlightedLinkIDs,
            hostViewBounds: hostViewBounds,
            visibleRect: visibleRect,
            layers: self.layers ?? [],
            activeLayerId: self.activeLayerId,
            snapProvider: snapProvider,
            items: resolvedItems,
            itemsBinding: itemsBinding,
            inputProcessors: self.inputProcessors,
            hitTargets: environment.hitTargets,
            canvasDragHandlers: canvasDragHandlers
        )
    }

    // MARK: - Viewport Event Handlers

    func viewportDidScroll(to newVisibleRect: CGRect) {
        environment.visibleRect = newVisibleRect
        view?.requestLayerUpdate() // Redraw for layers like Grid.
    }

    func viewportDidMagnify(to newMagnification: CGFloat) {
        self.magnification = newMagnification
        view?.requestLayerUpdate() // Redraw for magnification-dependent layers.
    }

    // MARK: - Interaction API

    func setInteractionHighlight(itemIDs: Set<UUID>, needsDisplay: Bool = true) {
        guard interactionHighlightedItemIDs != itemIDs else { return }
        interactionHighlightedItemIDs = itemIDs
        if needsDisplay {
            view?.requestLayerUpdate() // Redraw for transient highlights.
        }
    }

    func setInteractionLinkHighlight(linkIDs: Set<UUID>, needsDisplay: Bool = true) {
        guard interactionHighlightedLinkIDs != linkIDs else { return }
        interactionHighlightedLinkIDs = linkIDs
        if needsDisplay {
            view?.requestLayerUpdate()
        }
    }

    func updateSelection(_ ids: Set<UUID>, notify: Bool = true) {
        guard selectedItemIDs != ids else { return }
        selectedItemIDs = ids
        view?.requestLayerUpdate()
        if notify {
            onSelectionChange?(ids)
        }
    }

    func updateEnvironment(_ block: (inout CanvasEnvironmentValues) -> Void) {
        block(&environment)
        view?.requestLayerUpdate() // Redraw for transient state like Marquee.
    }
}
