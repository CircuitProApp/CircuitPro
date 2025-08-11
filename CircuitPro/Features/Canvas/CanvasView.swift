import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {
    
    // Bindings (from document)
    @Bindable var manager: CanvasManager
    @Bindable var schematicGraph: SchematicGraph
    @Binding var elements: [CanvasElement]
    @Binding var selectedIDs: Set<UUID>
    @Binding var selectedTool: AnyCanvasTool
    var layerBindings: CanvasLayerBindings? = nil
    var onComponentDropped: ((TransferableComponent, CGPoint) -> Void)?

    // Coordinator holds the controller and manages callbacks
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
            canvasController.onUpdateElements = { [weak self] newElements in
                 DispatchQueue.main.async {
                     self?.parent.elements = newElements
                 }
             }
             canvasController.onUpdateSelectedIDs = { [weak self] newIDs in
                 DispatchQueue.main.async {
                     self?.parent.selectedIDs = newIDs
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
        let controller = context.coordinator.canvasController
        let canvasHostView = CanvasHostView(controller: controller)

        // Wrapper view for shadow and centering
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
        let containerView = scrollView.documentView as! DocumentContainerView
        let hostView = containerView.canvasHostView

        // 1. Sync state FROM SwiftUI Bindings INTO the CanvasController
        controller.elements = elements
        controller.selectedIDs = selectedIDs
        controller.selectedTool = selectedTool
        controller.schematicGraph = schematicGraph
        
        // From CanvasManager
        controller.magnification = manager.magnification
        controller.isSnappingEnabled = manager.enableSnapping
        controller.snapGridSize = manager.gridSpacing.rawValue * 10.0
        controller.showGuides = manager.showGuides
        controller.crosshairsStyle = manager.crosshairsStyle
        controller.paperSize = manager.paperSize
        
        // Callbacks are now managed by the Coordinator

        // 2. Set the frame of the container and host views
        let workbenchSize = manager.paperSize.canvasSize(orientation: .landscape) // landscape temp
        let scaleFactor: CGFloat = 1.4
        let containerSize = CGSize(width: workbenchSize.width * scaleFactor, height: workbenchSize.height * scaleFactor)
        
        if containerView.frame.size != containerSize {
            containerView.frame.size = containerSize
        }
        if hostView.frame.size != workbenchSize {
            hostView.frame.size = workbenchSize
        }
        
        // 3. Trigger a redraw
        controller.redraw()
        
        // Sync external zoom changes
        if scrollView.magnification != manager.magnification {
            scrollView.magnification = manager.magnification
        }
    }
}
