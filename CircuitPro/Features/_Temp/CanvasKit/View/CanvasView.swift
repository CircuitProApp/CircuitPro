import SwiftUI
import AppKit

/// A generic, configurable, and extensible canvas component for SwiftUI on macOS.
///
/// This view manages a scene graph of `CanvasNode` objects and uses pluggable pipelines
/// for both rendering (`RenderLayer`) and user input (`CanvasInteraction`).
/// It is agnostic to the application's specific data model, which is passed in
/// via a `userInfo` dictionary in the `RenderContext`.
struct CanvasView: NSViewRepresentable {
    
    // MARK: - Framework Bindings
    @Binding var size: CGSize
    @Binding var magnification: CGFloat
    @Binding var nodes: [any CanvasNode]
    @Binding var selection: Set<UUID>
    @Binding var tool: AnyCanvasTool?
    
    // MARK: - Configuration Properties
    private let renderLayers: [RenderLayer]
    private let interactions: [any CanvasInteraction]
    private let userInfo: [String: Any]

    // MARK: - Initializer
    init(
        size: Binding<CGSize>,
        magnification: Binding<CGFloat>,
        nodes: Binding<[any CanvasNode]>,
        selection: Binding<Set<UUID>>,
        tool: Binding<AnyCanvasTool?> = .constant(nil),
        userInfo: [String: Any] = [:],
        renderLayers: [RenderLayer],
        interactions: [any CanvasInteraction]
    ) {
        self._size = size
        self._magnification = magnification
        self._nodes = nodes
        self._selection = selection
        self._tool = tool
        self.userInfo = userInfo
        self.renderLayers = renderLayers
        self.interactions = interactions
    }

    // MARK: - Coordinator
    final class Coordinator {
        let canvasController: CanvasController
        var parent: CanvasView

        init(_ parent: CanvasView) {
            self.parent = parent
            self.canvasController = CanvasController()
            setupCallbacks()
        }
        
        func updateParent(_ parent: CanvasView) {
            self.parent = parent
        }

        private func setupCallbacks() {
            canvasController.onUpdateSelectedNodes = { [weak self] newNodes in
                DispatchQueue.main.async {
                    self?.parent.selection = Set(newNodes.map { $0.id })
                }
            }
            canvasController.onNodesChanged = { [weak self] newNodes in
                self?.parent.nodes = newNodes
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - NSViewRepresentable Lifecycle
    func makeNSView(context: Context) -> NSScrollView {
        let controller = context.coordinator.canvasController
        
        controller.renderLayers = self.renderLayers
        controller.interactions = self.interactions
        
        let canvasHostView = CanvasHostView(controller: controller)
        
        for layer in controller.renderLayers {
            layer.install(on: canvasHostView.layer!)
        }
        
        let scrollView = NSScrollView()
        scrollView.documentView = canvasHostView
        
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        scrollView.drawsBackground = false
        
        // --- THIS IS THE FIX ---
        scrollView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coordinator = context.coordinator] _ in // We capture the coordinator from the context.
            // Safely unwrap the weak reference.
            guard let coordinator = coordinator else { return }
            
            let currentMagnification = scrollView.magnification
            if coordinator.parent.magnification != currentMagnification {
                DispatchQueue.main.async {
                    // Update the binding on the parent view stored in the coordinator.
                    coordinator.parent.magnification = currentMagnification
                }
            }
        }
        
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.updateParent(self)
        let controller = coordinator.canvasController
        
        guard let hostView = scrollView.documentView as? CanvasHostView else {
            return
        }
        
        if controller.selectedTool?.id != tool?.id {
            controller.selectedTool = tool
        }

        
        // 1. Sync data FROM SwiftUI bindings INTO the controller
        syncSceneGraph(controller: controller, from: nodes)
        syncSelection(controller: controller, from: selection)
        controller.magnification = magnification

        // 2. Assemble the definitive RenderContext for this frame.
        let renderContext = RenderContext(
            sceneRoot: controller.sceneRoot,
            magnification: controller.magnification,
            mouseLocation: controller.mouseLocation,
            selectedTool: controller.selectedTool,
            highlightedNodeIDs: Set(controller.selectedNodes.map { $0.id }),
            hostViewBounds: hostView.bounds,
            userInfo: self.userInfo
        )
        // Inject the final context into the host view.
        hostView.currentContext = renderContext
        
        // 3. Update the host view's frame size directly.
        if hostView.frame.size != size {
            hostView.frame.size = size
        }
        
        // 4. Trigger redraw and sync magnification.
        controller.redraw()
        if scrollView.magnification != magnification {
            scrollView.magnification = magnification
        }
    }
    
    // MARK: - Private Helpers
    private func syncSceneGraph(controller: CanvasController, from newNodes: [any CanvasNode]) {
        let currentNodes = controller.sceneRoot.children
        let currentNodeIDs = Set(currentNodes.map { $0.id })
        let newNodeIDs = Set(newNodes.map { $0.id })

        let nodesToRemove = currentNodes.filter { !newNodeIDs.contains($0.id) }
        for node in nodesToRemove { node.removeFromParent() }

        let nodesToAdd = newNodes.filter { !newNodeIDs.contains($0.id) }
        for node in nodesToAdd { controller.sceneRoot.addChild(node) }
    }
    
    private func syncSelection(controller: CanvasController, from selectedIDs: Set<UUID>) {
        let currentSelectedIDsInController = Set(controller.selectedNodes.map { $0.id })
        if currentSelectedIDsInController != selectedIDs {
             controller.selectedNodes = selectedIDs.compactMap { id in
                return findNode(with: id, in: controller.sceneRoot)
             }
        }
    }
    
    private func findNode(with id: UUID, in root: any CanvasNode) -> (any CanvasNode)? {
        if root.id == id { return root }
        for child in root.children {
            if let found = findNode(with: id, in: child) { return found }
        }
        return nil
    }
}
