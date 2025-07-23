//
//  CanvasOverlayView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

/// Abstract canvas overlay that draws with a `CAShapeLayer`.
class CanvasOverlayView: NSView {

    // MARK: - Stored properties
    fileprivate let shapeLayer = CAShapeLayer()
    var magnification: CGFloat = 1 { didSet { guard magnification != oldValue else { return }; updateDrawing() } }

    // MARK: - Init
    override init(frame: NSRect = .zero) {
        super.init(frame: frame)
        wantsLayer = true
        guard let hostLayer = layer else { fatalError("Expected a backing layer") }

        hostLayer.addSublayer(shapeLayer)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout
    override func layout() {
        super.layout()
        updateDrawing()                         // geometry may have changed
    }

    override func hitTest(_: NSPoint) -> NSView? { nil }   // stay transparent

    // MARK: - Template method
    func makeDrawingParameters() -> DrawingParameters? { fatalError("override me") }

    // MARK: - Drawing
    final func updateDrawing() {
        guard let p = makeDrawingParameters() else { shapeLayer.path = nil; return }

        CATransaction.begin(); CATransaction.setDisableActions(true)
        let scale = 1 / max(magnification, .ulpOfOne)

        shapeLayer.path          = p.path
        shapeLayer.fillColor     = p.fillColor
        shapeLayer.strokeColor   = p.strokeColor
        shapeLayer.lineCap       = p.lineCap
        shapeLayer.lineJoin      = p.lineJoin
        shapeLayer.lineWidth     = p.lineWidth * scale
        shapeLayer.lineDashPattern = p.lineDashPattern?.map { NSNumber(value: $0.doubleValue * scale) }
        CATransaction.commit()
    }
}
