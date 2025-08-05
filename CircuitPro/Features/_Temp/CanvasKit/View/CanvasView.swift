import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    @Binding var size: CGSize
    @Binding var magnification: CGFloat
    @Binding var nodes: [any CanvasNode]
    @Binding var selection: Set<UUID>
    @Binding var tool: AnyCanvasTool?

    private let renderLayers: [RenderLayer]
    private let interactions: [any CanvasInteraction]
    private let userInfo: [String: Any]

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

    final class Coordinator: NSObject {
        let canvasController: CanvasController
        
        // This token manages the lifetime of the KVO observation.
        private var magnificationObservation: NSKeyValueObservation?
        
        private var magnificationBinding: Binding<CGFloat>
        private var nodesBinding: Binding<[any CanvasNode]>
        private var selectionBinding: Binding<Set<UUID>>

        init(
            magnification: Binding<CGFloat>,
            nodes: Binding<[any CanvasNode]>,
            selection: Binding<Set<UUID>>
        ) {
            self.magnificationBinding = magnification
            self.nodesBinding = nodes
            self.selectionBinding = selection
            self.canvasController = CanvasController()
            super.init()
            setupCallbacks()
        }

        private func setupCallbacks() {
            canvasController.onUpdateSelectedNodes = { [weak self] newNodes in
                DispatchQueue.main.async {
                    self?.selectionBinding.wrappedValue = Set(newNodes.map { $0.id })
                }
            }
            canvasController.onNodesChanged = { [weak self] newNodes in
                DispatchQueue.main.async {
                    self?.nodesBinding.wrappedValue = newNodes
                }
            }
        }
        
        // This function sets up the KVO observation.
        func observeScrollView(_ scrollView: NSScrollView) {
            magnificationObservation = scrollView.observe(\.magnification, options: [.new]) { [weak self] _, change in
                guard let self = self, let newValue = change.newValue else { return }
                
                // When the scroll view's magnification changes (e.g., from a user gesture),
                // update the SwiftUI binding.
                self.magnificationBinding.wrappedValue = newValue
            }
        }
        
        // The coordinator must deinit the observation to prevent memory leaks.
        deinit {
            magnificationObservation?.invalidate()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            magnification: $magnification,
            nodes: $nodes,
            selection: $selection
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let controller = coordinator.canvasController

        controller.renderLayers = self.renderLayers
        controller.interactions = self.interactions

        let canvasHostView = CanvasHostView(controller: controller)
        let scrollView = NSScrollView()
        scrollView.documentView = canvasHostView
        
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        scrollView.drawsBackground = false
        
        // Instead of using NotificationCenter, we now ask the Coordinator to
        // directly observe the scroll view's magnification property.
        coordinator.observeScrollView(scrollView)
        
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator.canvasController
        
        guard let hostView = scrollView.documentView as? CanvasHostView else { return }
        
        if controller.selectedTool?.id != tool?.id {
            controller.selectedTool = tool
        }
        
        syncSceneGraph(controller: controller, from: nodes)
        syncSelection(controller: controller, from: selection)
        controller.magnification = magnification

        let renderContext = RenderContext(
            sceneRoot: controller.sceneRoot,
            magnification: magnification,
            mouseLocation: controller.mouseLocation,
            selectedTool: controller.selectedTool,
            highlightedNodeIDs: selection,
            hostViewBounds: hostView.bounds,
            userInfo: self.userInfo
        )
        hostView.currentContext = renderContext
        
        if hostView.frame.size != size {
            hostView.frame.size = size
        }
        
        controller.redraw()

        // This approximate check is still crucial. It prevents `updateNSView` from
        // programmatically setting the scroll view's magnification if the value
        // is already effectively the same, which prevents the KVO handler
        // from re-triggering this update cycle.
        if !scrollView.magnification.isApproximatelyEqual(to: magnification) {
            scrollView.magnification = magnification
        }
    }
    
    // MARK: - Private Helpers
    private func syncSceneGraph(controller: CanvasController, from newNodes: [any CanvasNode]) {
        let currentIDs = controller.sceneRoot.children.map { $0.id }
        let newIDs = newNodes.map { $0.id }

        if currentIDs != newIDs {
            controller.sceneRoot.children.forEach { $0.removeFromParent() }
            newNodes.forEach { controller.sceneRoot.addChild($0) }
        }
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

extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}
