//
//  CanvasController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit

final class CanvasController {
    // MARK: - Core Data Model
    
    let sceneRoot: BaseNode = BaseNode()
    var selectedNodes: [BaseNode] = []
    var interactionHighlightedNodeIDs: Set<UUID> = []
    
    // MARK: - Universal View State
    
    var magnification: CGFloat = 1.0
    var mouseLocation: CGPoint?
    var selectedTool: CanvasTool?
    
    var environment: CanvasEnvironmentValues = .init()
    
    var layers: [CanvasLayer] = []
    
    /// The ID of the currently active layer, if any.
    var activeLayerId: UUID?
    
    // MARK: - Pluggable Pipelines
    
    let renderLayers: [any RenderLayer]
    let interactions: [any CanvasInteraction]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider
    
    // MARK: - Callbacks to Owner
    
    var onNeedsRedraw: (() -> Void)?
    var onSelectionChanged: ((Set<UUID>) -> Void)?
    var onNodesChanged: (([BaseNode]) -> Void)?
    
    // New consolidated callback
    var onCanvasChange: ((CanvasChangeContext) -> Void)?
    
    /// A generic callback to notify the owner that a persistent model was mutated.
    var onModelDidChange: (() -> Void)?
    
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
    
    // MARK: - Public API
    
    /// The primary entry point for SwiftUI to push state updates *into* the controller.
    func sync(
        nodes: [BaseNode],
        selection: Set<UUID>,
        tool: CanvasTool?,
        magnification: CGFloat,
        environment: CanvasEnvironmentValues,
        layers: [CanvasLayer],
        activeLayerId: UUID?
    ) {
        
        nodes.forEach { node in
            node.onNeedsRedraw = self.redraw
        }
        
        let currentNodeIDs = Set(self.sceneRoot.children.map { $0.id })
        let newNodeIDs = Set(nodes.map { $0.id })
        
        if currentNodeIDs != newNodeIDs {
            sceneRoot.children.forEach { $0.removeFromParent() }
            nodes.forEach { node in
                sceneRoot.addChild(node)
            }
            let baseNodeChildren = sceneRoot.children.compactMap {
                $0 as? BaseNode
            }
            onNodesChanged?(baseNodeChildren)
        }
        
        let currentSelectedIDsInController = Set(
            self.selectedNodes.map { $0.id
            })
        
        if currentSelectedIDsInController != selection {
            self.selectedNodes = selection.compactMap { id in
                findNode(with: id, in: sceneRoot)
            }
        }
        
        if self.selectedTool?.id != tool?.id {
            self.selectedTool = tool
        }
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
            layers: self.layers,
            activeLayerId: self.activeLayerId,
            snapProvider: snapProvider,
            environment: self.environment,
            inputProcessors: self.inputProcessors
            
        )
    }
    
    /// Notifies the owner that the view needs to be redrawn.
    func redraw() {
        onNeedsRedraw?()
    }
    
    /// Allows interactions to update the current selection.
    func setSelection(to nodes: [BaseNode]) {
        self.selectedNodes = nodes
        self.onSelectionChanged?(Set(nodes.map { $0.id }))
    }
    
    /// Allows interactions to update the temporary highlight state.
    func setInteractionHighlight(nodeIDs: Set<UUID>) {
        self.interactionHighlightedNodeIDs = nodeIDs
        redraw()
    }
    
    /// Allows interactions to modify the environment and trigger a redraw.
    func updateEnvironment(_ block: (inout CanvasEnvironmentValues) -> Void) {
        block(&environment)
        redraw()
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

// In a new file like `BaseNode+Extensions.swift`

import Foundation

extension Collection where Element == BaseNode {
    /// Recursively finds the first node in the collection or its descendants that has the specified ID.
    ///
    /// - Parameter id: The `UUID` of the node to find.
    /// - Returns: The `BaseNode` if found; otherwise, `nil`.
    func findNode(with id: UUID) -> BaseNode? {
        for node in self {
            if let found = findNodeRecursive(with: id, in: node) {
                return found
            }
        }
        return nil
    }

    /// The recursive helper function that performs the depth-first search.
    private func findNodeRecursive(with id: UUID, in node: BaseNode) -> BaseNode? {
        if node.id == id {
            return node
        }
        
        // Search through the children of the current node.
        // This assumes `BaseNode` has a `children` property as implied by CanvasController.
        for child in node.children {
            if let childNode = child as? BaseNode {
                if let found = findNodeRecursive(with: id, in: childNode) {
                    return found
                }
            }
        }
        
        return nil
    }
}
