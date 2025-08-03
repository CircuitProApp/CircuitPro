import AppKit
import UniformTypeIdentifiers

final class CanvasHostView: NSView {

    private let controller: CanvasController
    private var inputCoordinator: WorkbenchInputCoordinator!

    // MARK: - Init & Setup
    init(controller: CanvasController) {
        self.controller = controller
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor // Background is handled by layers

        // Install render layers ONCE.
        for renderLayer in controller.renderLayers {
            renderLayer.install(on: self.layer!)
        }
        
        // The redraw callback now asynchronously invalidates the view.
        self.controller.onNeedsRedraw = { [weak self] in
            self?.needsDisplay = true // This is the asynchronous, non-hanging way.
        }

        self.inputCoordinator = WorkbenchInputCoordinator(host: self, controller: controller)
        self.registerForDraggedTypes([.transferableComponent])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // This tells AppKit that our view is layer-backed and that we
    // will be doing our drawing by updating layer properties.
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    // **NEW:** The drawing logic moves from `draw(_:)` to `updateLayer()`.
    // This is the correct method for a high-performance, layer-backed view.
    override func updateLayer() {
        let context = self.currentContext()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Simply tell each layer to update its persistent CALayers.
        for renderLayer in controller.renderLayers {
            renderLayer.update(using: context)
        }
        
        CATransaction.commit()
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateTrackingAreas()
    }
    
    // A private helper to create the context, keeping updateLayers clean.
    private func currentContext() -> RenderContext {
        return RenderContext(
            // Data
            elements: controller.elements,
            schematicGraph: controller.schematicGraph,

            // View State
            selectedIDs: controller.selectedIDs,
            marqueeSelectedIDs: controller.marqueeSelectedIDs,
            magnification: controller.magnification,
            selectedTool: controller.selectedTool,

            // Interaction State
            mouseLocation: controller.mouseLocation,
            marqueeRect: controller.marqueeRect,

            // Configuration
            paperSize: controller.paperSize,
            sheetOrientation: controller.sheetOrientation,
            sheetCellValues: controller.sheetCellValues,
            snapGridSize: controller.snapGridSize,
            showGuides: controller.showGuides,
            crosshairsStyle: controller.crosshairsStyle,
            
            // CORRECTED: Use 'self' to refer to the view's own bounds.
            hostViewBounds: self.bounds
        )
    }

    // MARK: - Input & Tracking (This section is unchanged)
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }
    
    override func mouseMoved(with event: NSEvent) { inputCoordinator.mouseMoved(event) }
    override func mouseEntered(with event: NSEvent) { inputCoordinator.mouseMoved(event) }
    override func mouseExited(with event: NSEvent) { inputCoordinator.mouseExited() }
    override func mouseDown(with event: NSEvent) { inputCoordinator.mouseDown(event) }
    override func mouseDragged(with event: NSEvent) { inputCoordinator.mouseDragged(event) }
    override func mouseUp(with event: NSEvent) { inputCoordinator.mouseUp(event) }
    override func rightMouseDown(with event: NSEvent) { inputCoordinator.rightMouseDown(event) }
    override func keyDown(with event: NSEvent) {
        if !inputCoordinator.keyDown(event) { super.keyDown(with: event) }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { inputCoordinator.draggingEntered(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { inputCoordinator.draggingUpdated(sender) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { inputCoordinator.performDragOperation(sender) }
}

extension NSPasteboard.PasteboardType {
    static let transferableComponent = NSPasteboard.PasteboardType(UTType.transferableComponent.identifier)
}
