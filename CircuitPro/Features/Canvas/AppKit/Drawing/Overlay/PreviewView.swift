//
//  PreviewView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

/// Renders a preview of the currently selected tool's action.
final class PreviewView: CanvasOverlayView {

    // MARK: - API

    /// The currently active tool. The view will ask this tool for a preview.
    /// The overlay is redrawn when the tool changes.
    var selectedTool: AnyCanvasTool? {
        didSet {
            guard oldValue?.id != selectedTool?.id else { return }
            updateDrawing()
        }
    }

    /// A reference to the main workbench, providing context for the tool.
    weak var workbench: WorkbenchView? {
        didSet { updateDrawing() }
    }
    
    // MARK: - State
    
    /// The last known location of the mouse, in view coordinates.
    private var mouseLocation: CGPoint? {
        didSet {
            guard oldValue != mouseLocation else { return }
            updateDrawing()
        }
    }

    // MARK: - Mouse Tracking

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        // 1. Clean up old tracking area
        if let currentTrackingArea = trackingArea {
            removeTrackingArea(currentTrackingArea)
        }
        
        // 2. Create new tracking area
        // We need to know when the mouse moves over this view to update the preview.
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let newTrackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
        
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        // Update the location and trigger a redraw.
        self.mouseLocation = convert(event.locationInWindow, from: nil)
    }
    
    override func mouseExited(with event: NSEvent) {
        // Hide the preview when the mouse leaves the view.
        self.mouseLocation = nil
    }

    // MARK: - Drawing

    /// Generates drawing parameters by asking the active tool for a preview.
    override func makeDrawingParameters() -> DrawingParameters? {
        // 1. Validate State
        guard var tool = selectedTool,
              tool.id != "cursor",
              let workbench = workbench,
              let mouse = mouseLocation
        else {
            return nil
        }

        // 2. Create Tool Context
        let pinCount = workbench.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 }
        let padCount = workbench.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 }
        let context = CanvasToolContext(
            existingPinCount: pinCount,
            existingPadCount: padCount,
            selectedLayer: workbench.selectedLayer,
            magnification: magnification,
            schematicGraph: workbench.schematicGraph
        )

        // 3. Get Drawing Parameters from Tool
        let snappedMouse = workbench.snap(mouse)
        let drawingParams = tool.preview(mouse: snappedMouse, context: context)
        
        // 4. Persist Tool State
        workbench.selectedTool = tool
        
        // 5. Return parameters directly
        // No conversion from ToolPreview is needed anymore.
        return drawingParams
    }
}
