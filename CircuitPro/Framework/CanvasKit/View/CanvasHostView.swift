// Features/_Temp/CanvasKit/View/CanvasHostView.swift
import AppKit
import UniformTypeIdentifiers

final class CanvasHostView: NSView {

    private let controller: CanvasController
    private let inputHandler: CanvasInputHandler
    private let dragDropHandler: CanvasDragDropHandler

    // MARK: - Init & Setup
    init(controller: CanvasController, registeredDraggedTypes: [NSPasteboard.PasteboardType]) {
        self.controller = controller
        self.inputHandler = CanvasInputHandler(controller: controller)
        self.dragDropHandler = CanvasDragDropHandler(controller: controller)

        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.white.cgColor

        self.controller.onNeedsRedraw = { [weak self] in
            DispatchQueue.main.async {
                self?.performLayerUpdate()
            }
        }
        
        // This is the correct way to register types. The NSView superclass
        // handles storing and exposing this list via its own `registeredDraggedTypes` property.
        self.registerForDraggedTypes(registeredDraggedTypes)

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
        performLayerUpdate()
    }
    
    func performLayerUpdate() {
        let context = controller.currentContext(for: self.bounds, visibleRect: self.visibleRect)

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
    
    // MARK: - Event Forwarding (Mouse)

    override func mouseMoved(with event: NSEvent) { inputHandler.mouseMoved(event, in: self) }
    override func mouseExited(with event: NSEvent) { inputHandler.mouseExited() }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        
        inputHandler.mouseDown(event, in: self)
    }
    override func mouseDragged(with event: NSEvent) { inputHandler.mouseDragged(event, in: self) }
    override func mouseUp(with event: NSEvent) { inputHandler.mouseUp(event, in: self) }
    
    override func keyDown(with event: NSEvent) {
        // Ask the input handler to process the event.
        let wasHandledByInteraction = inputHandler.keyDown(event, in: self)
        
        // If our custom interactions (like ToolKeyInteraction) did NOT handle
        // the event, we MUST pass it up the responder chain. This allows
        // SwiftUI's .keyboardShortcut to receive it.
        if !wasHandledByInteraction {
            super.keyDown(with: event)
        }
    }
    
    // MARK: - Event Forwarding (Drag and Drop)
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return dragDropHandler.draggingEntered(sender, in: self)
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return dragDropHandler.draggingUpdated(sender, in: self)
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        dragDropHandler.draggingExited(sender, in: self)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        
        let wasHandled = dragDropHandler.performDragOperation(sender, in: self)

        
        if wasHandled {
            window?.makeFirstResponder(self)
        }
        
        return wasHandled
    }
}
