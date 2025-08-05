import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: - SwiftUI State Bindings
    @Binding var size: CGSize
    @Binding var magnification: CGFloat
    @Binding var nodes: [any CanvasNode]
    @Binding var selection: Set<UUID>
    @Binding var tool: AnyCanvasTool?

    // MARK: - Static Configuration
    let renderLayers: [RenderLayer]
    let interactions: [any CanvasInteraction]
    let userInfo: [String: Any]

    // MARK: - Coordinator
    
    /// The Coordinator is the bridge. It owns the `CanvasController` and connects SwiftUI bindings
    /// to the controller's callbacks.
    final class Coordinator: NSObject {
        let canvasController: CanvasController
        
        // Store bindings to update SwiftUI state from controller callbacks.
        private var magnificationBinding: Binding<CGFloat>
        private var selectionBinding: Binding<Set<UUID>>
        private var nodesBinding: Binding<[any CanvasNode]>

        // KVO token for observing the scroll view's magnification.
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

            // Set up the callbacks to propagate changes from the controller *out* to SwiftUI.
            setupControllerCallbacks()
        }

        private func setupControllerCallbacks() {
            // When an interaction changes the selection in the controller...
            canvasController.onSelectionChanged = { [weak self] newSelectionIDs in
                // ...update the SwiftUI binding on the main thread.
                DispatchQueue.main.async {
                    self?.selectionBinding.wrappedValue = newSelectionIDs
                }
            }

            // When nodes are added or removed...
            canvasController.onNodesChanged = { [weak self] newNodes in
                DispatchQueue.main.async {
                    self?.nodesBinding.wrappedValue = newNodes
                }
            }
            
            // When the controller's magnification changes (e.g., from KVO)...
            canvasController.onMagnificationChanged = { [weak self] newMagnification in
                DispatchQueue.main.async {
                     if let bindingValue = self?.magnificationBinding.wrappedValue,
                        !bindingValue.isApproximatelyEqual(to: newMagnification) {
                         self?.magnificationBinding.wrappedValue = newMagnification
                     }
                }
            }
        }
        
        /// Sets up KVO to watch for magnification changes from user gestures (e.g., pinch-to-zoom).
        func observeScrollView(_ scrollView: NSScrollView) {
            magnificationObservation = scrollView.observe(\.magnification, options: .new) { [weak self] _, change in
                guard let self = self, let newValue = change.newValue else { return }
                
                // When the scroll view's magnification changes, update the controller's state.
                // The controller will then trigger the `onMagnificationChanged` callback.
                self.canvasController.magnification = newValue
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
        let controller = coordinator.canvasController

        let canvasHostView = CanvasHostView(controller: controller)
        
        let scrollView = NSScrollView()
        scrollView.documentView = canvasHostView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        
        // Have the coordinator start listening for magnification gestures.
        coordinator.observeScrollView(scrollView)
        
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator.canvasController
        
        // Push all state changes from SwiftUI *into* the controller.
        controller.sync(
            nodes: self.nodes,
            selection: self.selection,
            tool: self.tool,
            magnification: self.magnification,
            userInfo: self.userInfo
        )
        
        // Ensure the AppKit views are correctly sized.
        if let hostView = scrollView.documentView, hostView.frame.size != self.size {
            hostView.frame.size = self.size
        }
        
        // Programmatically set the scroll view's magnification if the binding changes.
        // This check prevents an infinite loop with the KVO observer.
        if !scrollView.magnification.isApproximatelyEqual(to: self.magnification) {
            scrollView.magnification = self.magnification
        }
        
        // Trigger a redraw. The host view will ask the controller for a fresh RenderContext.
        scrollView.documentView?.needsDisplay = true
    }
}

// Helper remains the same
extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}
