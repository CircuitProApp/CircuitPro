import AppKit
import UniformTypeIdentifiers

/// The AppKit view that directly hosts the canvas's rendering layers and receives raw input events.
/// This view is now stateless regarding the render context.
final class CanvasHostView: NSView {

    private let controller: CanvasController
    private let inputHandler: CanvasInputHandler

    // MARK: - Init & Setup
    init(controller: CanvasController) {
        self.controller = controller
        self.inputHandler = CanvasInputHandler(controller: controller)
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.white.cgColor

        self.controller.onNeedsRedraw = { [weak self] in
            DispatchQueue.main.async {
                self?.needsDisplay = true
            }
        }

        self.registerForDraggedTypes([.transferableComponent])

        for renderLayer in controller.renderLayers {
            renderLayer.install(on: self.layer!)
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Core Rendering Logic

    override var wantsUpdateLayer: Bool {
        return true
    }
    
    override func updateLayer() {

        let context = controller.currentContext(for: self.bounds)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
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

    override func mouseMoved(with event: NSEvent) { inputHandler.mouseMoved(event, in: self) }
    override func mouseExited(with event: NSEvent) { inputHandler.mouseExited() }
    override func mouseDown(with event: NSEvent) { inputHandler.mouseDown(event, in: self) }
    override func mouseDragged(with event: NSEvent) { inputHandler.mouseDragged(event, in: self) }
    override func mouseUp(with event: NSEvent) { inputHandler.mouseUp(event, in: self) }
}
