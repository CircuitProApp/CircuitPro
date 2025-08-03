//
//  CanvasHostView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


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
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        self.controller.onNeedsRedraw = { [weak self] in
            self?.needsDisplay = true
        }

        self.inputCoordinator = WorkbenchInputCoordinator(host: self, controller: controller)
        
        self.registerForDraggedTypes([.transferableComponent])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateTrackingAreas()
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        let context = RenderContext(
            elements: controller.elements,
            schematicGraph: controller.schematicGraph,
            selectedIDs: controller.selectedIDs,
            marqueeSelectedIDs: controller.marqueeSelectedIDs,
            magnification: controller.magnification,
            selectedTool: controller.selectedTool,
            mouseLocation: controller.mouseLocation,
            marqueeRect: controller.marqueeRect,
            paperSize: controller.paperSize,
            sheetOrientation: controller.sheetOrientation,
            sheetCellValues: controller.sheetCellValues,
            snapGridSize: controller.snapGridSize,
            showGuides: controller.showGuides,
            crosshairsStyle: controller.crosshairsStyle,
            hostViewBounds: self.bounds
        )
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        self.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        for renderLayer in controller.renderLayers {
            let layers = renderLayer.makeLayers(context: context)
            for layer in layers {
                self.layer?.addSublayer(layer)
            }
        }
        
        CATransaction.commit()
    }

    // MARK: - Input & Tracking
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil))
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
