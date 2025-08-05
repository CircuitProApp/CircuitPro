import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: - SwiftUI State Bindings
    @Binding var size: CGSize
    @Binding var magnification: CGFloat
    @Binding var nodes: [any CanvasNode]
    @Binding var selection: Set<UUID>
    @Binding var tool: CanvasTool?

    // MARK: - Static Configuration
    let renderLayers: [RenderLayer]
    let interactions: [any CanvasInteraction]
    
    let environment: CanvasEnvironmentValues
    
    init(
        size: Binding<CGSize>,
        magnification: Binding<CGFloat>,
        nodes: Binding<[any CanvasNode]>,
        selection: Binding<Set<UUID>>,
        tool: Binding<CanvasTool?> = .constant(nil),
        environment: CanvasEnvironmentValues = .init(), // Default allows for easy adoption
        renderLayers: [RenderLayer],
        interactions: [any CanvasInteraction]
    ) {
        self._size = size
        self._magnification = magnification
        self._nodes = nodes
        self._selection = selection
        self._tool = tool
        self.environment = environment
        self.renderLayers = renderLayers
        self.interactions = interactions
    }

    // MARK: - Coordinator
    
    final class Coordinator: NSObject {
        let canvasController: CanvasController
        private var magnificationBinding: Binding<CGFloat>
        private var selectionBinding: Binding<Set<UUID>>
        private var nodesBinding: Binding<[any CanvasNode]>
        private var magnificationObservation: NSKeyValueObservation?

        init(
            magnification: Binding<CGFloat>,
            nodes: Binding<[any CanvasNode]>,
            selection: Binding<Set<UUID>>,
            renderLayers: [RenderLayer],
            interactions: [any CanvasInteraction]
        ) {
            self.magnificationBinding = magnification
            self.nodesBinding = nodes
            self.selectionBinding = selection
            self.canvasController = CanvasController(renderLayers: renderLayers, interactions: interactions)
            super.init()
            setupControllerCallbacks()
        }

        private func setupControllerCallbacks() {
            canvasController.onSelectionChanged = { [weak self] newSelectionIDs in
                DispatchQueue.main.async { self?.selectionBinding.wrappedValue = newSelectionIDs }
            }
            canvasController.onNodesChanged = { [weak self] newNodes in
                DispatchQueue.main.async { self?.nodesBinding.wrappedValue = newNodes }
            }
        }
        
        func observeScrollView(_ scrollView: NSScrollView) {
             magnificationObservation = scrollView.observe(\.magnification, options: .new) { [weak self] _, change in
                 guard let self = self, let newValue = change.newValue else { return }
                 
                 DispatchQueue.main.async {
                     if !self.magnificationBinding.wrappedValue.isApproximatelyEqual(to: newValue) {
                         self.magnificationBinding.wrappedValue = newValue
                     }
                 }
             }
         }
        
        deinit {
            magnificationObservation?.invalidate()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            magnification: $magnification,
            nodes: $nodes,
            selection: $selection,
            renderLayers: self.renderLayers,
            interactions: self.interactions
        )
    }

    // MARK: - NSViewRepresentable Lifecycle

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let canvasHostView = CanvasHostView(controller: coordinator.canvasController)
        let scrollView = NSScrollView()
        scrollView.documentView = canvasHostView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        coordinator.observeScrollView(scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator.canvasController
        
        controller.sync(
            nodes: self.nodes,
            selection: self.selection,
            tool: self.tool,
            magnification: self.magnification,
            environment: self.environment
        )
        
        if let hostView = scrollView.documentView, hostView.frame.size != self.size {
            hostView.frame.size = self.size
        }
        
        if !scrollView.magnification.isApproximatelyEqual(to: self.magnification) {
            scrollView.magnification = self.magnification
        }
        
        scrollView.documentView?.needsDisplay = true
    }
}

// Helper remains the same
extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}
