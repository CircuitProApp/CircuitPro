//
//  CanvasController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit

final class CanvasController {

    // MARK: - Core Data Model

    /// The root of the internal scene graph. Its children are the nodes displayed on the canvas.
    let sceneRoot: BaseNode = BaseNode()
    var interactionHighlightedNodeIDs: Set<UUID> = []

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
    var layers: [CanvasLayer]?
    var activeLayerId: UUID?
    var graph: CanvasGraph?

    // MARK: - Pluggable Pipelines

    let renderLayers: [any RenderLayer]
    let interactions: [any CanvasInteraction]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider

    // MARK: - Callbacks to Owner

    var onCanvasChange: ((CanvasChangeContext) -> Void)?
    var onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?

    // MARK: - Init

    init(
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor],
        snapProvider: any SnapProvider
    ) {
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
    }

    // MARK: - State Syncing API

    /// The primary entry point for SwiftUI to push state updates *into* the controller.
    func sync(
        tool: CanvasTool?,
        magnification: CGFloat,
        environment: CanvasEnvironmentValues,
        layers: [CanvasLayer]?,
        activeLayerId: UUID?,
        graph: CanvasGraph? = nil
    ) {
        // --- Other State ---
        if self.selectedTool?.id != tool?.id { self.selectedTool = tool }
        self.magnification = magnification
        self.environment.merge(environment)
        self.layers = layers
        self.activeLayerId = activeLayerId
        self.graph = graph
    }

    /// Creates a definitive, non-optional RenderContext for a given drawing pass.
    func currentContext(for hostViewBounds: CGRect, visibleRect: CGRect) -> RenderContext {
        var allHighlightedIDs = interactionHighlightedNodeIDs
        allHighlightedIDs.formUnion(graph?.selection.map { $0.rawValue } ?? [])

        return RenderContext(
            sceneRoot: self.sceneRoot,
            magnification: self.magnification,
            mouseLocation: self.mouseLocation,
            selectedTool: self.selectedTool,
            highlightedNodeIDs: allHighlightedIDs,
            hostViewBounds: hostViewBounds,
            visibleRect: visibleRect,
            layers: self.layers ?? [],
            activeLayerId: self.activeLayerId,
            snapProvider: snapProvider,
            graph: graph,
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

    func setInteractionHighlight(nodeIDs: Set<UUID>) {
        guard self.interactionHighlightedNodeIDs != nodeIDs else { return }
        self.interactionHighlightedNodeIDs = nodeIDs
        view?.performLayerUpdate() // Redraw for transient highlights.
    }

    func updateEnvironment(_ block: (inout CanvasEnvironmentValues) -> Void) {
        block(&environment)
        view?.performLayerUpdate() // Redraw for transient state like Marquee.
    }
}
