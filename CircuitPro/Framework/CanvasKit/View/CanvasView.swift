import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: - SwiftUI State
    
    // The viewport binding remains two-way.
    @Binding var viewport: CanvasViewport
    
    // MODIFICATION 1: `nodes` is now a read-only stored property.
    // It is no longer a @Binding because data flows one way: from the controller to the view.
    let nodes: [BaseNode]

    // Other bindings for state that can be mutated by the canvas remain.
    @Binding var selection: Set<UUID>
    @Binding var tool: CanvasTool?
    @Binding var layers: [CanvasLayer]
    @Binding var activeLayerId: UUID?

    // MARK: - Callbacks & Configuration
    let environment: CanvasEnvironmentValues
    let renderLayers: [any RenderLayer]
    let interactions: [any CanvasInteraction]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider
    
    let registeredDraggedTypes: [NSPasteboard.PasteboardType]
    let onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?
    var onCanvasChange: ((CanvasChangeContext) -> Void)?

    // MODIFICATION 2: Updated initializer to accept a plain `[BaseNode]`.
    init(
        viewport: Binding<CanvasViewport>,
        nodes: [BaseNode], // <-- No longer a Binding
        selection: Binding<Set<UUID>>,
        tool: Binding<CanvasTool?> = .constant(nil),
        layers: Binding<[CanvasLayer]> = .constant([]),
        activeLayerId: Binding<UUID?> = .constant(nil),
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil,
    ) {
        self._viewport = viewport
        self.nodes = nodes // Standard assignment
        self._selection = selection
        self._tool = tool
        self._layers = layers
        self._activeLayerId = activeLayerId
        self.environment = environment
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.registeredDraggedTypes = registeredDraggedTypes
        self.onPasteboardDropped = onPasteboardDropped
    }

    // MARK: - Coordinator
    
    final class Coordinator: NSObject {
        let canvasController: CanvasController
        
        private var viewportBinding: Binding<CanvasViewport>
        private var selectionBinding: Binding<Set<UUID>>
        
        // MODIFICATION 3: nodesBinding is GONE. The coordinator no longer needs to write back to it.
        // private var nodesBinding: Binding<[BaseNode]>
        
        private var magnificationObservation: NSKeyValueObservation?
        private var boundsChangeObserver: Any?

        init(
            viewport: Binding<CanvasViewport>,
            // nodes binding is removed from here
            selection: Binding<Set<UUID>>,
            renderLayers: [any RenderLayer],
            interactions: [any CanvasInteraction],
            inputProcessors: [any InputProcessor],
            snapProvider: any SnapProvider
        ) {
            self.viewportBinding = viewport
            self.selectionBinding = selection
            self.canvasController = CanvasController(renderLayers: renderLayers, interactions: interactions, inputProcessors: inputProcessors, snapProvider: snapProvider)
            super.init()
            setupControllerCallbacks()
        }

        private func setupControllerCallbacks() {
            canvasController.onSelectionChanged = { [weak self] newSelectionIDs in
                DispatchQueue.main.async { self?.selectionBinding.wrappedValue = newSelectionIDs }
            }
            // MODIFICATION 4: onNodesChanged callback is REMOVED.
            // The canvas no longer mutates the external nodes array.
            // canvasController.onNodesChanged = { ... }
        }
        
        // ... (observeScrollView and deinit are unchanged) ...
        func observeScrollView(_ scrollView: NSScrollView) { /* ... same as before ... */ }
        deinit { /* ... same as before ... */ }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            viewport: $viewport,
            // $nodes is removed from the coordinator's init
            selection: $selection,
            renderLayers: self.renderLayers,
            interactions: self.interactions,
            inputProcessors: self.inputProcessors,
            snapProvider: self.snapProvider
        )
        // ... (wiring up other callbacks is unchanged) ...
        coordinator.canvasController.onPasteboardDropped = self.onPasteboardDropped
        coordinator.canvasController.onCanvasChange = self.onCanvasChange
        return coordinator
    }

    // MARK: - NSViewRepresentable Lifecycle

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let canvasHostView = CanvasHostView(controller: coordinator.canvasController, registeredDraggedTypes: self.registeredDraggedTypes)
        let scrollView = CenteringNSScrollView()
        
        
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
        controller.onCanvasChange = self.onCanvasChange
        
        // The call to `controller.sync` is now simplified.
        // It reads from the plain `nodes` property.
        controller.sync(
            nodes: self.nodes,
            selection: self.selection,
            tool: self.tool,
            magnification: self.viewport.magnification,
            environment: self.environment,
            layers: self.layers,
            activeLayerId: self.activeLayerId
        )
        
        // ... (The rest of updateNSView for viewport syncing is unchanged) ...
        if let hostView = scrollView.documentView, hostView.frame.size != self.viewport.size {
            hostView.frame.size = self.viewport.size
        }
        
        if !scrollView.magnification.isApproximatelyEqual(to: self.viewport.magnification) {
            scrollView.magnification = self.viewport.magnification
        }
        
        if let clipView = scrollView.contentView as? NSClipView {
            if self.viewport.visibleRect != CanvasViewport.autoCenter && clipView.bounds.origin != self.viewport.visibleRect.origin {
                clipView.bounds.origin = self.viewport.visibleRect.origin
            }
        }
        
        scrollView.documentView?.needsDisplay = true
    }
}

// ... (CGFloat extension is unchanged) ...
extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}
