import AppKit

final class CanvasController {
    // MARK: - Core Data Model
    
    // The scene graph is now built on the concrete BaseNode class.
    let sceneRoot: BaseNode = BaseNode()
    var selectedNodes: [BaseNode] = []
    var interactionHighlightedNodeIDs: Set<UUID> = []

    // MARK: - Universal View State

    var magnification: CGFloat = 1.0
    var mouseLocation: CGPoint?
    var selectedTool: CanvasTool?
    
    // The environment model remains the same.
    var environment: CanvasEnvironmentValues = .init()

    // MARK: - Pluggable Pipelines

    let renderLayers: [any RenderLayer]
    let interactions: [any CanvasInteraction]

    // MARK: - Callbacks to Owner
    
    // These callbacks now use the concrete BaseNode type where appropriate.
    var onNeedsRedraw: (() -> Void)?
    var onSelectionChanged: ((Set<UUID>) -> Void)?
    var onNodesChanged: (([BaseNode]) -> Void)?
    var onMouseMoved: ((CGPoint?) -> Void)? // Added for consistency with our previous design.

    // MARK: - Init

    init(renderLayers: [any RenderLayer], interactions: [any CanvasInteraction]) {
        self.renderLayers = renderLayers
        self.interactions = interactions
    }

    // MARK: - Public API

    /// The primary entry point for SwiftUI to push state updates *into* the controller.
    func sync(
        nodes: [BaseNode],
        selection: Set<UUID>,
        tool: CanvasTool?,
        magnification: CGFloat,
        environment: CanvasEnvironmentValues
    ) {
        // --- FIX: Always ensure the redraw callback is hooked up ---
        // This is the most critical change. We iterate over the source-of-truth nodes
        // from SwiftUI and guarantee that their callback is connected to our redraw
        // method. This is cheap to do and protects against view lifecycle issues
        // where node instances might be recreated.
        nodes.forEach { node in
            node.onNeedsRedraw = self.redraw
        }

        let currentNodeIDs = Set(self.sceneRoot.children.map { $0.id })
        let newNodeIDs = Set(nodes.map { $0.id })
        
        // The rest of your existing logic for updating the scene graph is fine.
        // Since the callbacks are now set on the `nodes` instances, this will work correctly.
        if currentNodeIDs != newNodeIDs {
            sceneRoot.children.forEach { $0.removeFromParent() }
            nodes.forEach { node in
                sceneRoot.addChild(node)
            }
            let baseNodeChildren = sceneRoot.children.compactMap { $0 as? BaseNode }
            onNodesChanged?(baseNodeChildren)
        }
        
        // The selection and tool syncing remains the same.
        let currentSelectedIDsInController = Set(self.selectedNodes.map { $0.id })
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
        print("[3] Controller SYNC: Internal environment updated to: \(self.environment.configuration.grid.spacing.rawValue)")
    }
    
    /// Creates a definitive, non-optional RenderContext for a given drawing pass.
    func currentContext(for hostViewBounds: CGRect) -> RenderContext {
        let selectedIDs = Set(self.selectedNodes.map { $0.id })
        let allHighlightedIDs = selectedIDs.union(interactionHighlightedNodeIDs)

        return RenderContext(
            sceneRoot: self.sceneRoot,
            magnification: self.magnification,
            mouseLocation: self.mouseLocation,
            selectedTool: self.selectedTool,
            highlightedNodeIDs: allHighlightedIDs,
            hostViewBounds: hostViewBounds,
            environment: self.environment
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
        
        // --- FIX 3: Correct Recursive Search ---
        // We must safely cast each child from `any CanvasNode` to `BaseNode`
        // before making the recursive call.
        for child in root.children {
            if let childNode = child as? BaseNode,
               let found = findNode(with: id, in: childNode) {
                return found
            }
        }
        return nil
    }
}
