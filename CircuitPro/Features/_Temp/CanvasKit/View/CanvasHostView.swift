import AppKit
import UniformTypeIdentifiers

/// The AppKit view that directly hosts the canvas's rendering layers and receives raw input events.
///
/// This view is intentionally "dumb". It does not contain any application-specific logic.
/// It is configured by the parent `CanvasView`, which injects a `RenderContext` on every
/// update cycle. Its sole responsibilities are to forward input events to the pluggable
/// interaction pipeline and to trigger the rendering pipeline.
final class CanvasHostView: NSView {

    private let controller: CanvasController
    var inputCoordinator: WorkbenchInputCoordinator!

    /// The definitive snapshot of the canvas state for the current frame.
     /// - NOTE: This is now a standard optional (?) instead of an implicitly
     ///   unwrapped one (!). This makes our code safer by forcing us to
     ///   handle the case where input events arrive before the first render pass.
     var currentContext: RenderContext?

    // MARK: - Init & Setup
    init(controller: CanvasController) {
        self.controller = controller
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.white.cgColor

        self.controller.onNeedsRedraw = { [weak self] in
            DispatchQueue.main.async {
                self?.needsDisplay = true
            }
        }

        self.inputCoordinator = WorkbenchInputCoordinator(host: self, controller: controller)
        self.registerForDraggedTypes([.transferableComponent])

        // --- THIS IS THE FIX ---
        // This is the crucial step that was missing. It calls the one-time
        // install method on each render layer, giving them a chance
        // to add their persistent CALayers to the host.
        for renderLayer in controller.renderLayers {
            renderLayer.install(on: self.layer!)
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Core Rendering Logic

    /// This property tells AppKit that we are a layer-backed view and will be performing
    /// our drawing by directly manipulating the properties of our `CALayer`.
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    /// This method is called by AppKit whenever the view needs to be redrawn.
    /// This is the heart of our high-performance rendering loop.
    override func updateLayer() {
        // Guard against the first frame before the context has been injected.
        guard let context = self.currentContext else { return }
        
        // By wrapping the updates in a transaction with actions disabled, we ensure
        // all layer changes happen simultaneously without any unwanted animations.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Pass the definitive context to each configured render layer to perform its drawing.
        for renderLayer in controller.renderLayers {
            renderLayer.update(using: context)
        }
        
        CATransaction.commit()
    }
    
    // MARK: - Input & Tracking Area

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateTrackingAreas()
        
    }
    
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }
    
    // MARK: - Event Forwarding
    // All raw AppKit events are unconditionally forwarded to the input coordinator.
    
    override func mouseMoved(with event: NSEvent) { inputCoordinator.mouseMoved(event) }
    override func mouseEntered(with event: NSEvent) { inputCoordinator.mouseMoved(event) }
    override func mouseExited(with event: NSEvent) { inputCoordinator.mouseExited() }
    override func mouseDown(with event: NSEvent) { inputCoordinator.mouseDown(event) }
    override func mouseDragged(with event: NSEvent) { inputCoordinator.mouseDragged(event) }
    override func mouseUp(with event: NSEvent) { inputCoordinator.mouseUp(event) }
    override func rightMouseDown(with event: NSEvent) { /* Forward to coordinator if needed */ }
    override func keyDown(with event: NSEvent) { /* Forward to coordinator if needed */ }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { /* Forward to coordinator if needed */ return [] }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { /* Forward to coordinator if needed */ return [] }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { /* Forward to coordinator if needed */ return false }
}


// MARK: - Pasteboard Type
// This is a static extension, so it's fine to keep it co-located with the NSView.
extension NSPasteboard.PasteboardType {
    static let transferableComponent = NSPasteboard.PasteboardType(UTType.transferableComponent.identifier)
}
