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
    var selectedNodes: [BaseNode] = []
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
    
    // MARK: - Pluggable Pipelines
    
    let renderLayers: [any RenderLayer]
    let interactions: [any CanvasInteraction]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider
    
    // MARK: - Callbacks to Owner
    
    var onSelectionChanged: ((Set<UUID>) -> Void)?
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
        nodes: [BaseNode],
        selection: Set<UUID>,
        tool: CanvasTool?,
        magnification: CGFloat,
        environment: CanvasEnvironmentValues,
        layers: [CanvasLayer]?,
        activeLayerId: UUID?
    ) {
        // --- Smart Node Syncing Logic ---
        // This diffing approach is the perfect balance of performance and simplicity.
        // It avoids destroying/recreating existing nodes if they haven't changed,
        // but doesn't require a complex `update(from:)` method on the nodes themselves.
        let newNodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let oldNodeIDs = Set(sceneRoot.children.map { $0.id })
        let newNodeIDs = Set(newNodesByID.keys)
        
        // 1. Remove nodes that are no longer in the new set.
        if oldNodeIDs != newNodeIDs {
            let nodesToRemove = oldNodeIDs.subtracting(newNodeIDs)
            sceneRoot.children.removeAll { nodesToRemove.contains($0.id) }
        }

        // 2. Add new nodes that weren't there before and re-order all children.
        //    By re-assigning the whole array, we ensure the render order is correct.
        sceneRoot.children = nodes.map { newNode in
            // Re-parent the node to our sceneRoot.
            newNode.parent = sceneRoot
            return newNode
        }
        
        // --- Selection Syncing ---
        let currentSelectedIDs = Set(self.selectedNodes.map { $0.id })
        if currentSelectedIDs != selection {
            self.selectedNodes = selection.compactMap { id in findNode(with: id, in: sceneRoot) }
        }
        
        // --- Other State ---
        if self.selectedTool?.id != tool?.id { self.selectedTool = tool }
        self.magnification = magnification
        self.environment.configuration = environment.configuration
        self.layers = layers
        self.activeLayerId = activeLayerId
    }
    
    /// Creates a definitive, non-optional RenderContext for a given drawing pass.
    func currentContext(for hostViewBounds: CGRect, visibleRect: CGRect) -> RenderContext {
        let selectedIDs = Set(self.selectedNodes.map { $0.id })
        let allHighlightedIDs = selectedIDs.union(interactionHighlightedNodeIDs)
        
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
    
    func setSelection(to nodes: [BaseNode]) {
        self.selectedNodes = nodes
        self.onSelectionChanged?(Set(nodes.map { $0.id }))
    }
    
    func setInteractionHighlight(nodeIDs: Set<UUID>) {
        guard self.interactionHighlightedNodeIDs != nodeIDs else { return }
        self.interactionHighlightedNodeIDs = nodeIDs
        view?.performLayerUpdate() // Redraw for transient highlights.
    }
    
    func updateEnvironment(_ block: (inout CanvasEnvironmentValues) -> Void) {
        block(&environment)
        view?.performLayerUpdate() // Redraw for transient state like Marquee.
    }
    
    /// Recursively finds a node in the scene graph.
    func findNode(with id: UUID, in root: BaseNode) -> BaseNode? {
        if root.id == id { return root }
        for child in root.children {
            if let childNode = child as? BaseNode,
               let found = findNode(with: id, in: childNode) {
                return found
            }
        }
        return nil
    }
}
