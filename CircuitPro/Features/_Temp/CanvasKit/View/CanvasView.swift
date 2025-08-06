import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: - SwiftUI State Bindings
    @Binding var size: CGSize
    @Binding var magnification: CGFloat
    // The nodes binding now correctly and consistently uses the concrete `BaseNode` class.
    @Binding var nodes: [BaseNode]
    @Binding var selection: Set<UUID>
    @Binding var tool: CanvasTool?

    // MARK: - Callbacks & Configuration
    let environment: CanvasEnvironmentValues
    let renderLayers: [any RenderLayer]
    let interactions: [any CanvasInteraction]
    // An optional callback to report the mouse's position to the parent view.
    var onMouseMoved: ((CGPoint?) -> Void)?
    
    // --- The init is now complete ---
    init(
        size: Binding<CGSize>,
        magnification: Binding<CGFloat>,
        nodes: Binding<[BaseNode]>,
        selection: Binding<Set<UUID>>,
        tool: Binding<CanvasTool?> = .constant(nil),
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        onMouseMoved: ((CGPoint?) -> Void)? = nil
    ) {
        self._size = size
        self._magnification = magnification
        self._nodes = nodes
        self._selection = selection
        self._tool = tool
        self.environment = environment
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.onMouseMoved = onMouseMoved
    }

    // MARK: - Coordinator
    
    final class Coordinator: NSObject {
        let canvasController: CanvasController
        private var magnificationBinding: Binding<CGFloat>
        private var selectionBinding: Binding<Set<UUID>>
        private var nodesBinding: Binding<[BaseNode]>
        private var magnificationObservation: NSKeyValueObservation?

        init(
            magnification: Binding<CGFloat>,
            nodes: Binding<[BaseNode]>,
            selection: Binding<Set<UUID>>,
            renderLayers: [any RenderLayer],
            interactions: [any CanvasInteraction]
        ) {
            self.magnificationBinding = magnification
            self.nodesBinding = nodes
            self.selectionBinding = selection
            self.canvasController = CanvasController(renderLayers: renderLayers, interactions: interactions)
            super.init()
            // Callbacks are configured when the coordinator is created.
            setupControllerCallbacks()
        }

        private func setupControllerCallbacks() {
            // Data flow: Controller -> Coordinator -> SwiftUI State
            canvasController.onSelectionChanged = { [weak self] newSelectionIDs in
                DispatchQueue.main.async { self?.selectionBinding.wrappedValue = newSelectionIDs }
            }
            // `newNodes` is now correctly typed as `[BaseNode]`, so no casting is needed.
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
        let coordinator = Coordinator(
            magnification: $magnification,
            nodes: $nodes,
            selection: $selection,
            renderLayers: self.renderLayers,
            interactions: self.interactions
        )
        // Pass the `onMouseMoved` callback from the view struct to the controller.
        coordinator.canvasController.onMouseMoved = self.onMouseMoved
        return coordinator
    }

    // MARK: - NSViewRepresentable Lifecycle

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let canvasHostView = CanvasHostView(controller: coordinator.canvasController)
        let scrollView = NSScrollView()
        
        // --- FIX 1: Wire up the redraw callback ---
        // This is the crucial connection that allows inspector edits to trigger an
        // immediate canvas update without lag. We do this once when the view is created.
        coordinator.canvasController.onNeedsRedraw = { [weak canvasHostView] in
            // When the controller says it needs a redraw, we tell the host view.
            canvasHostView?.needsDisplay = true
        }

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
        
        print("[2] CanvasView UPDATE: Receiving environment with grid spacing: \(self.environment.configuration.grid.spacing.rawValue)")

        // --- FIX 2: Correct Data Sync ---
        // This call is now much more efficient, passing a consistent concrete type
        // and allowing the controller to perform its logic cleanly.
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
        
        // A final redraw is triggered after syncing to ensure UI is up-to-date.
        scrollView.documentView?.needsDisplay = true
    }
}

// Helper remains the same
extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}
