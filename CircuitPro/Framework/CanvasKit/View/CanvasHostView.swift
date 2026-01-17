//
//  CanvasHostView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit
import UniformTypeIdentifiers

final class CanvasHostView: NSView {

    private let controller: CanvasController
    private let inputHandler: CanvasInputHandler
    private let dragDropHandler: CanvasDragDropHandler
    private var isLayerUpdatePending = false

    // MARK: - Init & Setup
    init(controller: CanvasController, registeredDraggedTypes: [NSPasteboard.PasteboardType]) {
        self.controller = controller
        self.inputHandler = CanvasInputHandler(controller: controller)
        self.dragDropHandler = CanvasDragDropHandler(controller: controller)

        super.init(frame: .zero)

        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.white.cgColor

        self.registerForDraggedTypes(registeredDraggedTypes)

        controller.renderer.install(on: self.layer!)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Core Rendering Logic

    override var wantsUpdateLayer: Bool {
        return true
    }

    override func updateLayer() {
        performLayerUpdate()
    }

    func requestLayerUpdate() {
        guard !isLayerUpdatePending else { return }
        isLayerUpdatePending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isLayerUpdatePending = false
            self.performLayerUpdate()
        }
    }

    func performLayerUpdate() {
        let context = controller.currentContext(for: self.bounds, visibleRect: self.visibleRect)
        self.layer?.backgroundColor = controller.environment.canvasTheme.backgroundColor

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        controller.environment.hitTargets.reset()
        controller.canvasDragHandlers.reset()
        var views = controller.renderViews
        views.append(ToolPreviewView())
        controller.renderer.render(views: views, context: context, environment: controller.environment)

        CATransaction.commit()
    }

    // MARK: - Input & Tracking Area

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        window?.acceptsMouseMovedEvents = true
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
        let wasHandledByInteraction = inputHandler.keyDown(event, in: self)

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
            updateTrackingAreas()
        }

        return wasHandled
    }
}
