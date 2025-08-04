import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {
    
    // MARK: - Universal Bindings
    @Bindable var manager: CanvasManager
    @Binding var selectedIDs: Set<UUID>
    @Binding var selectedTool: AnyCanvasTool
    
    // MARK: - Data Sources (Provide one)
    var designComponents: [DesignComponent]? = nil
    var symbolElements: [CanvasElement]? = nil
    
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
        context.coordinator.updateParent(self)
        let controller = context.coordinator.canvasController
        
        // --- THIS IS THE NEW DATA HANDLING LOGIC ---
        
        // 1. Tell the controller to build its scene from the provided data.
        if let components = designComponents {
            // controller.rebuildScene(from: components) // Implement this on the controller
        } else if let elements = symbolElements {
            // We need a way to build from primitives. For now, we can bridge it.
           /*  controller.rebuildSceneFromElements(elements)*/ // Implement this on the controller
        }
        
        // 2. Sync selection FROM SwiftUI -> Controller
        let currentSelectedIDs = Set(controller.selectedNodes.map { $0.id })
        if currentSelectedIDs != selectedIDs {
             controller.selectedNodes = selectedIDs.compactMap { id in
                // This requires a helper to find nodes by ID.
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
    
    // Helper to find a node by its ID in the scene graph.
    private func findNode(with id: UUID, in root: any CanvasNode) -> (any CanvasNode)? {
        if root.id == id { return root }
        for child in root.children {
            if let found = findNode(with: id, in: child) { return found }
        }
        return nil
    }
}
