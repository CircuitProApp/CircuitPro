import AppKit

/// A lean, generic controller that manages the universal state and pipelines of a canvas instance.
/// This is a plain class, fully decoupled from SwiftUI's state management.
final class CanvasController {
    // MARK: - Core Data Model
    let sceneRoot: any CanvasNode = BaseNode()
    var selectedNodes: [any CanvasNode] = []

    // MARK: - Universal View State
    var magnification: CGFloat = 1.0
    var mouseLocation: CGPoint?
    var selectedTool: CanvasTool?
    
    private(set) var environment: CanvasEnvironmentValues = .init()

    // MARK: - Pluggable Pipelines
    let renderLayers: [RenderLayer]
    let interactions: [any CanvasInteraction]

    // MARK: - Callbacks to Owner (The Coordinator)
    var onNeedsRedraw: (() -> Void)?
    var onSelectionChanged: ((Set<UUID>) -> Void)?
    var onNodesChanged: (([any CanvasNode]) -> Void)?

    // MARK: - Init
    init(renderLayers: [RenderLayer], interactions: [any CanvasInteraction]) {
        self.renderLayers = renderLayers
        self.interactions = interactions
    }

    // MARK: - Public API

    /// The primary entry point for SwiftUI to push state updates *into* the controller.
    /// This is called from `updateNSView`.
    func sync(
        nodes: [any CanvasNode],
        selection: Set<UUID>,
        tool: CanvasTool?,
        magnification: CGFloat,
        environment: CanvasEnvironmentValues
    ) {
        // Sync the scene graph if the nodes have changed.
        let currentNodeIDs = self.sceneRoot.children.map { $0.id }
        let newNodeIDs = nodes.map { $0.id }
        if currentNodeIDs != newNodeIDs {
            sceneRoot.children.forEach { $0.removeFromParent() }
            nodes.forEach { sceneRoot.addChild($0) }
            onNodesChanged?(sceneRoot.children)
        }
        
        // Sync selection state if it differs from the binding.
        let currentSelectedIDsInController = Set(self.selectedNodes.map { $0.id })
        if currentSelectedIDsInController != selection {
            self.selectedNodes = selection.compactMap { id in
                findNode(with: id, in: sceneRoot)
            }
        }
        
        // Sync other state properties.
        if self.selectedTool?.id != tool?.id {
            self.selectedTool = tool
        }
        self.magnification = magnification
        self.environment = environment
    }
    
    /// Creates a definitive, non-optional RenderContext for a given drawing pass.
    /// This is called by the `CanvasHostView` during rendering or by interactions.
    func currentContext(for hostViewBounds: CGRect) -> RenderContext {
        return RenderContext(
            sceneRoot: self.sceneRoot,
            magnification: self.magnification,
            mouseLocation: self.mouseLocation,
            selectedTool: self.selectedTool,
            highlightedNodeIDs: Set(self.selectedNodes.map { $0.id }),
            hostViewBounds: hostViewBounds,
            environment: self.environment
        )
    }
    
    /// Notifies the owner that the view needs to be redrawn.
    func redraw() {
        onNeedsRedraw?()
    }

    /// Allows interactions to update the current selection.
    func setSelection(to nodes: [any CanvasNode]) {
        self.selectedNodes = nodes
        self.onSelectionChanged?(Set(nodes.map { $0.id }))
    }

    /// Recursively finds a node in the scene graph.
    func findNode(with id: UUID, in root: any CanvasNode) -> (any CanvasNode)? {
        if root.id == id { return root }
        for child in root.children {
            if let found = findNode(with: id, in: child) { return found }
        }
        return nil
    }
}
