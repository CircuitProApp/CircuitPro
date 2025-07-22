//
//  PreviewView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

final class PreviewView: NSView {

    // MARK: - Public API

    var selectedTool: AnyCanvasTool? {
        didSet {
            if oldValue?.id != selectedTool?.id {
                updatePath()
            }
        }
    }

    var magnification: CGFloat = 1.0 {
        didSet {
            if oldValue != magnification {
                updatePath()
            }
        }
    }

    private var mouseLocation: CGPoint? {
        didSet {
            if oldValue != mouseLocation {
                updatePath()
            }
        }
    }

    weak var workbench: WorkbenchView? {
        didSet { updatePath() }
    }

    // MARK: - Init

    private let shapeLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer = CALayer()
        layer?.isGeometryFlipped = true // match NSView coords

        // Shape layer setup
        shapeLayer.fillColor   = nil
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        shapeLayer.lineCap     = .round
        layer?.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Mouse Tracking

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        if let trackingArea {
            addTrackingArea(trackingArea)
        }
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        self.mouseLocation = convert(event.locationInWindow, from: nil)
    }
    
    override func mouseExited(with event: NSEvent) {
        self.mouseLocation = nil
    }

    // MARK: - Layout & Drawing

    override func layout() {
        super.layout()
        shapeLayer.frame = bounds
        updatePath()
    }

    /// Rebuilds the vector path when state changes.
    private func updatePath() {
        // The tool can change, so we need a var
        guard var tool = selectedTool,
              tool.id != "cursor",
              let workbench = workbench,
              let mouse = mouseLocation else {
            shapeLayer.path = nil
            return
        }

        let pinCount = workbench.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 }
        let padCount = workbench.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 }

        let ctxInfo = CanvasToolContext(
            existingPinCount: pinCount,
            existingPadCount: padCount,
            selectedLayer: workbench.selectedLayer,
            magnification: magnification,
            schematicGraph: workbench.schematicGraph
        )

        let snappedMouse = workbench.snap(mouse)

        let preview = tool.preview(mouse: snappedMouse, context: ctxInfo)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let preview {
            shapeLayer.path = preview.path
            shapeLayer.fillColor = preview.fillColor
            shapeLayer.strokeColor = preview.strokeColor
            // Adjust line width for magnification, but don't let it become zero
            shapeLayer.lineWidth = preview.lineWidth / max(magnification, 0.01)
            shapeLayer.lineDashPattern = preview.lineDashPattern
            shapeLayer.lineCap = preview.lineCap
            shapeLayer.lineJoin = preview.lineJoin
        } else {
            shapeLayer.path = nil
        }

        CATransaction.commit()

        // Persist any state changes the tool might have made
        workbench.selectedTool = tool
    }

    // MARK: - Hit-testing

    /// This view is only an overlay – it should never intercept events.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}