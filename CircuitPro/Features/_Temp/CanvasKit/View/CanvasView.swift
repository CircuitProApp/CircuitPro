import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {
    
    // MARK: - Universal Bindings
    @Bindable var manager: CanvasManager
    @Binding var selectedIDs: Set<UUID>
    @Binding var selectedTool: AnyCanvasTool

    @Binding var nodes: [any CanvasNode]

    // MARK: - Schematics-Only Data
    var schematicGraph: SchematicGraph? = nil
    
    // MARK: - Callbacks
    var onComponentDropped: ((TransferableComponent, CGPoint) -> Void)?

    // The Coordinator now handles the node-based selection callback.
    final class Coordinator {
        let canvasController: CanvasController
        private var parent: CanvasView

        init(_ parent: CanvasView) {
            self.parent = parent
            self.canvasController = CanvasController()
            setupCallbacks()
            
            // Give the controller a way to modify the parent's node array.
            self.canvasController.onNodesChanged = { [weak self] newNodes in
                self?.parent.nodes = newNodes
            }
        }
        
        func updateParent(_ parent: CanvasView) {
            self.parent = parent
        }

        private func setupCallbacks() {
            // Callback from Controller -> SwiftUI
            canvasController.onUpdateSelectedNodes = { [weak self] newNodes in
                 DispatchQueue.main.async {
                     self?.parent.selectedIDs = Set(newNodes.map { $0.id })
                 }
             }
             canvasController.onUpdateSelectedTool = { [weak self] newTool in
                 DispatchQueue.main.async {
                     self?.parent.selectedTool = newTool
                 }
             }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // This logic remains the same.
        let controller = context.coordinator.canvasController
        let canvasHostView = CanvasHostView(controller: controller)
        let containerView = DocumentContainerView(canvasHost: canvasHostView)
        let scrollView = CenteringNSScrollView()
        scrollView.documentView = containerView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = ZoomStep.minZoom
        scrollView.maxMagnification = ZoomStep.maxZoom
        scrollView.drawsBackground = false
        
        scrollView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak manager = self.manager] _ in
            guard let manager = manager else { return }
            let origin = scrollView.contentView.bounds.origin
            let clip = scrollView.contentView.bounds.size
            let boardHeight = containerView.bounds.height
            let flippedY = boardHeight - origin.y - clip.height
            manager.scrollOrigin = CGPoint(x: origin.x, y: flippedY)
            manager.magnification = scrollView.magnification
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.updateParent(self)
        let controller = coordinator.canvasController
        
        // --- SMARTER DATA SYNCING ---
        
        // 1. Sync the controller's scene graph to match the bound 'nodes' array.
        // This is more efficient than clearing and re-adding everything every time.
        syncSceneGraph(controller: controller, from: nodes)
        
        // 2. Sync selection FROM SwiftUI -> Controller
        let currentSelectedIDsInController = Set(controller.selectedNodes.map { $0.id })
        if currentSelectedIDsInController != selectedIDs {
             controller.selectedNodes = selectedIDs.compactMap { id in
                return findNode(with: id, in: controller.sceneRoot)
             }
        }
        
        // 3. Sync other state properties into the controller.
        controller.selectedTool = selectedTool
        if let graph = schematicGraph { controller.schematicGraph = graph }
        
        controller.magnification = manager.magnification
        controller.isSnappingEnabled = manager.enableSnapping
        controller.snapGridSize = manager.gridSpacing.rawValue * 10.0
        controller.showGuides = manager.showGuides
        controller.crosshairsStyle = manager.crosshairsStyle
        controller.paperSize = manager.paperSize
        
        // 4. Update view frames (Unchanged).
        let containerView = scrollView.documentView as! DocumentContainerView
        let hostView = containerView.canvasHostView
        let workbenchSize = manager.paperSize.canvasSize(orientation: .landscape)
        let scaleFactor: CGFloat = 1.4
        let containerSize = CGSize(width: workbenchSize.width * scaleFactor, height: workbenchSize.height * scaleFactor)
        if containerView.frame.size != containerSize { containerView.frame.size = containerSize }
        if hostView.frame.size != workbenchSize { hostView.frame.size = workbenchSize }
        
        // 5. Trigger redraw and sync zoom.
        controller.redraw()
        if scrollView.magnification != manager.magnification {
            scrollView.magnification = manager.magnification
        }
    }
    
    /// Diffs the nodes from the binding with the nodes in the scene graph and applies the changes.
    private func syncSceneGraph(controller: CanvasController, from newNodes: [any CanvasNode]) {
        let currentNodes = controller.sceneRoot.children
        let currentNodeIDs = Set(currentNodes.map { $0.id })
        let newNodeIDs = Set(newNodes.map { $0.id })

        // Remove nodes that are no longer in the source array
        let nodesToRemove = currentNodes.filter { !newNodeIDs.contains($0.id) }
        for node in nodesToRemove {
            node.removeFromParent()
        }

        // Add nodes that are new in the source array
        let nodesToAdd = newNodes.filter { !currentNodeIDs.contains($0.id) }
        for node in nodesToAdd {
            controller.sceneRoot.addChild(node)
        }
        
        // TODO: Could also implement updating/reordering here if necessary
    }
    
    // Helper to find a node by its ID in the scene graph.
    private func findNode(with id: UUID, in root: any CanvasNode) -> (any CanvasNode)? {
        if root.id == id { return root }
        for child in root.children {
            if let found = findNode(with: id, in: child) { return found }
        }
        return nil
    }
}
