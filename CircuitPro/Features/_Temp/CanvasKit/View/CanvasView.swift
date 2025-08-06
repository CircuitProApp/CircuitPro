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
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider
    // An optional callback to report the mouse's position to the parent view.
    var onMouseMoved: ((CGPoint?) -> Void)?

    init(
        size: Binding<CGSize>,
        magnification: Binding<CGFloat>,
        nodes: Binding<[BaseNode]>,
        selection: Binding<Set<UUID>>,
        tool: Binding<CanvasTool?> = .constant(nil),
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
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
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.onMouseMoved = onMouseMoved
    }

    // MARK: - Coordinator
    
    final class Coordinator: NSObject {
        let canvasController: CanvasController
        private var magnificationBinding: Binding<CGFloat>
        private var selectionBinding: Binding<Set<UUID>>
        private var nodesBinding: Binding<[BaseNode]>
        private var magnificationObservation: NSKeyValueObservation?
        // --- MODIFICATION 1: Changed property to hold the notification observer ---
        private var boundsChangeObserver: Any?

        init(
            magnification: Binding<CGFloat>,
            nodes: Binding<[BaseNode]>,
            selection: Binding<Set<UUID>>,
            renderLayers: [any RenderLayer],
            interactions: [any CanvasInteraction],
            inputProcessors: [any InputProcessor],
            snapProvider: any SnapProvider
        ) {
            self.magnificationBinding = magnification
            self.nodesBinding = nodes
            self.selectionBinding = selection
            self.canvasController = CanvasController(renderLayers: renderLayers, interactions: interactions, inputProcessors: inputProcessors, snapProvider: snapProvider)
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
            
    
            guard let clipView = scrollView.contentView as? NSClipView else { return }
            
            // First, you must explicitly enable these notifications.
            clipView.postsBoundsChangedNotifications = true
            
            // Second, observe the notification that is now being posted.
            self.boundsChangeObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                // Any change to the bounds (i.e., a pan) will trigger a redraw.
                self?.canvasController.redraw()
            }
        }
        
        deinit {
            magnificationObservation?.invalidate()
            // --- MODIFICATION 3: Clean up the new observer correctly ---
            if let observer = boundsChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            magnification: $magnification,
            nodes: $nodes,
            selection: $selection,
            renderLayers: self.renderLayers,
            interactions: self.interactions,
            inputProcessors: self.inputProcessors, snapProvider: self.snapProvider
        )
        coordinator.canvasController.onMouseMoved = self.onMouseMoved
        return coordinator
    }

    // MARK: - NSViewRepresentable Lifecycle

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let canvasHostView = CanvasHostView(controller: coordinator.canvasController)
        let scrollView = NSScrollView()
        
        coordinator.canvasController.onNeedsRedraw = { [weak canvasHostView] in
            canvasHostView?.performLayerUpdate()
        }

        scrollView.documentView = canvasHostView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        
        // This line now sets up both magnification and the new bounds observation
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

extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}
