//
//  MarqueeView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 14.06.25.
//

import AppKit

/// Vector-based selection marquee.
/// Uses a CAShapeLayer instead of bitmap rasterisation, so zooming no longer
/// allocates a huge backing store.
final class MarqueeView: NSView {

    // MARK: – Public API -----------------------------------------------------

    /// Selection rectangle in *world / view* coordinates (y-down).
    /// Pass `nil` to hide the marquee.
    var rect: CGRect? {
        didSet { updatePath() }
    }

    /// Current scroll-view magnification (used to keep the stroke 1-pixel wide).
    var magnification: CGFloat = 1 {
        didSet { updatePath() }
    }

    // MARK: – Init -----------------------------------------------------------

    private let shapeLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer = CALayer()                          // container only
        layer?.isGeometryFlipped = true            // match NSView coords
        layer?.masksToBounds = false

        // Shape-layer styling
        shapeLayer.fillColor   = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        shapeLayer.lineCap     = .butt
        shapeLayer.lineJoin    = .miter
        layer?.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: – Layout & drawing ----------------------------------------------

    override var isOpaque: Bool { false }          // keep overlay transparent

    override func layout() {
        super.layout()
        shapeLayer.frame = bounds                  // follow view size
        updatePath()
    }

    /// Rebuilds the vector path and stroke when state changes.
    private func updatePath() {

        guard let r = rect else {                  // hide if nil
            shapeLayer.path = nil
            return
        }

        let dashBase: [CGFloat] = [4, 2]           // in points @ 1× zoom
        let scale                 = 1 / max(magnification, 0.01)

        CATransaction.begin()
        CATransaction.setDisableActions(true)      // no implicit fades

        // Path
        shapeLayer.path      = CGPath(rect: r, transform: nil)

        // Stroke + dash pattern stay 1-pixel wide
        shapeLayer.lineWidth = scale
        shapeLayer.lineDashPattern = dashBase.map { NSNumber(value: Double($0 * scale)) }

        CATransaction.commit()
    }

    // MARK: – Hit-testing ----------------------------------------------------

    override func hitTest(_ point: NSPoint) -> NSView? { nil } // overlay only
}
