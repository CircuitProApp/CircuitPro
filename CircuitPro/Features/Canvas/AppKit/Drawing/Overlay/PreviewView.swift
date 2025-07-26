//
//  PreviewView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

/// Renders a model-space preview of the currently selected tool's action.
final class PreviewView: NSView {

    // MARK: - API
    var selectedTool: AnyCanvasTool? {
        didSet {
            // The guard `oldValue?.id != selectedTool?.id` was removed because
            // a tool's internal state (e.g., rotation) can change without its
            // ID changing. We need to redraw the preview in those cases.
            updateDrawing()
        }
    }
    weak var workbench: WorkbenchView? {
        didSet { updateDrawing() }
    }
    var magnification: CGFloat = 1 {
        didSet {
            // While the preview lines don't scale, a tool might change its preview
            // based on zoom level (e.g. showing more detail), so we still need to redraw.
            guard magnification != oldValue else { return }
            updateDrawing()
        }
    }
    
    // MARK: - State
    private var shapeLayers: [CAShapeLayer] = []
    private var mouseLocation: CGPoint?

    // MARK: - Initializers
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - Overrides
    override func hitTest(_: NSPoint) -> NSView? { nil } // Stay transparent

    // MARK: - Public API
    /// Called by the input coordinator to update the mouse position.
    func updateMouseLocation(to point: CGPoint?) {
        guard point != mouseLocation else { return }
        mouseLocation = point
        updateDrawing()
    }

    // MARK: - Drawing
    /// Asks the active tool for its preview and renders it.
    private func updateDrawing() {
        let parametersArray = makeDrawingParameters()

        CATransaction.begin(); CATransaction.setDisableActions(true)

        // 1. Synchronize the number of layers.
        while shapeLayers.count < parametersArray.count {
            let newLayer = CAShapeLayer()
            layer?.addSublayer(newLayer)
            shapeLayers.append(newLayer)
        }
        while shapeLayers.count > parametersArray.count {
            shapeLayers.popLast()?.removeFromSuperlayer()
        }

        // 2. Configure each layer with its corresponding parameters WITHOUT scaling.
        for (params, shapeLayer) in zip(parametersArray, shapeLayers) {
            shapeLayer.path           = params.path
            shapeLayer.fillColor      = params.fillColor
            shapeLayer.strokeColor    = params.strokeColor
            shapeLayer.lineCap        = params.lineCap
            shapeLayer.lineJoin       = params.lineJoin
            shapeLayer.fillRule       = params.fillRule
            
            // This is the critical difference: We apply the values directly.
            // A lineWidth of 1.0 remains 1.0 in the model, and will appear
            // thicker as you zoom in, correctly previewing the final object.
            shapeLayer.lineWidth      = params.lineWidth
            shapeLayer.lineDashPattern = params.lineDashPattern
        }
        
        CATransaction.commit()
    }
    
    /// Generates drawing parameters by asking the active tool for a preview.
    private func makeDrawingParameters() -> [DrawingParameters] {
        guard var tool = selectedTool,
              tool.id != "cursor",
              let workbench = workbench,
              let mouse = mouseLocation
        else {
            return []
        }

        let context = CanvasToolContext(
            existingPinCount: workbench.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 },
            existingPadCount: workbench.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 },
            selectedLayer: workbench.selectedLayer,
            magnification: magnification,
            schematicGraph: workbench.schematicGraph
        )

        let snappedMouse = workbench.snap(mouse)
        let drawingParams = tool.preview(mouse: snappedMouse, context: context)
        
        return drawingParams
    }
}
