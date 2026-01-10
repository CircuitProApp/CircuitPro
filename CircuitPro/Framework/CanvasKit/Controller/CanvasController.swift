//
//  CanvasController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit

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

    var magnification: CGFloat = 1.0

    private var _rawMouseLocation: CGPoint?
    var mouseLocation: CGPoint? {
        get { _rawMouseLocation }
        set {
            guard _rawMouseLocation != newValue else { return }
            _rawMouseLocation = newValue
            view?.performLayerUpdate() // Redraw for layers like Crosshairs.
        }
    }

    var selectedTool: CanvasTool?
    var environment: CanvasEnvironmentValues = .init()
    var layers: [any CanvasLayer]?
    var activeLayerId: UUID?
    var items: [any CanvasItem] = []

    // MARK: - Pluggable Pipelines

    let renderLayers: [any CKRenderLayer]
    let interactions: [any CanvasInteraction]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider
    let renderer: CKRenderer

    // MARK: - Callbacks to Owner

    var onCanvasChange: ((CanvasChangeContext) -> Void)?
    var onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?

    // MARK: - Init

    init(
        renderLayers: [any CKRenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor],
        snapProvider: any SnapProvider,
        renderer: CKRenderer = DefaultCKRenderer()
    ) {
        self.renderLayers = renderLayers
        self.interactions = interactions
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
        items: [any CanvasItem]
    ) {
        // --- Other State ---
        if self.selectedTool?.id != tool?.id { self.selectedTool = tool }
        self.magnification = magnification
        self.environment.merge(environment)
        self.layers = layers
        self.activeLayerId = activeLayerId
        updateSelection(selectedItemIDs, notify: false)
        self.items = items
    }

    /// Creates a definitive, non-optional RenderContext for a given drawing pass.
    func currentContext(for hostViewBounds: CGRect, visibleRect: CGRect) -> RenderContext {
        var allHighlightedIDs = interactionHighlightedItemIDs
        allHighlightedIDs.formUnion(selectedItemIDs)
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
            items: items,
            environment: self.environment,
            inputProcessors: self.inputProcessors
        )
    }

    // MARK: - Viewport Event Handlers

    func viewportDidScroll(to newVisibleRect: CGRect) {
        view?.performLayerUpdate() // Redraw for layers like Grid.
    }

    func viewportDidMagnify(to newMagnification: CGFloat) {
        self.magnification = newMagnification
        view?.performLayerUpdate() // Redraw for magnification-dependent layers.
    }

    // MARK: - Interaction API

    func setInteractionHighlight(itemIDs: Set<UUID>) {
        guard interactionHighlightedItemIDs != itemIDs else { return }
        interactionHighlightedItemIDs = itemIDs
        view?.performLayerUpdate() // Redraw for transient highlights.
    }

    func setInteractionLinkHighlight(linkIDs: Set<UUID>) {
        guard interactionHighlightedLinkIDs != linkIDs else { return }
        interactionHighlightedLinkIDs = linkIDs
        view?.performLayerUpdate()
    }

    func updateSelection(_ ids: Set<UUID>, notify: Bool = true) {
        guard selectedItemIDs != ids else { return }
        selectedItemIDs = ids
        view?.performLayerUpdate()
        if notify {
            onSelectionChange?(ids)
        }
    }

    func updateEnvironment(_ block: (inout CanvasEnvironmentValues) -> Void) {
        block(&environment)
        view?.performLayerUpdate() // Redraw for transient state like Marquee.
    }
}
