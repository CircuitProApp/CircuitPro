import AppKit

/// Vector-based cross-hairs overlay.
/// Uses a CAShapeLayer so memory stays flat even at high magnification.
final class CrosshairsView: NSView {

    // MARK: – Public API -----------------------------------------------------

    var crosshairsStyle: CrosshairsStyle = .centeredCross {
        didSet { updatePath() }
    }

    /// Point in **view coordinates** (y-down).
    /// Pass `nil` to hide when style is not `.hidden`.
    var location: CGPoint? {
        didSet { updatePath() }
    }

    /// Current scroll-view magnification (used only for stroke width).
    var magnification: CGFloat = 1.0 {
        didSet { updatePath() }
    }

    // MARK: – Init -----------------------------------------------------------

    private let shapeLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true                              // we need a backing layer
        layer = CALayer()                              // plain container
        layer?.isGeometryFlipped = true                // match NSView coords

        // Shape layer setup
        shapeLayer.fillColor   = nil
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        shapeLayer.lineCap     = .round
        layer?.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: – Layout & drawing ----------------------------------------------

    override func layout() {
        super.layout()
        shapeLayer.frame = bounds
        updatePath()
    }

    /// Rebuilds the vector path when state changes.
    private func updatePath() {

        // Nothing to draw?
        guard crosshairsStyle != .hidden,
              let p = location else {
            shapeLayer.path = nil
            return
        }

        let path = CGMutablePath()
        switch crosshairsStyle {
        case .fullScreenLines:
            path.move(to: CGPoint(x: p.x, y: 0))
            path.addLine(to: CGPoint(x: p.x, y: bounds.height))
            path.move(to: CGPoint(x: 0,  y: p.y))
            path.addLine(to: CGPoint(x: bounds.width, y: p.y))

        case .centeredCross:
            let size: CGFloat = 20.0
            let half = size / 2
            path.move(to: CGPoint(x: p.x - half, y: p.y))
            path.addLine(to: CGPoint(x: p.x + half, y: p.y))
            path.move(to: CGPoint(x: p.x, y: p.y - half))
            path.addLine(to: CGPoint(x: p.x, y: p.y + half))

        case .hidden:      // already handled above
            break
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)          // avoid implicit fades
        shapeLayer.lineWidth = 1.0 / max(magnification, 0.01)
        shapeLayer.path      = path
        CATransaction.commit()
    }

    // MARK: – Hit-testing ----------------------------------------------------

    /// This view is only an overlay – it should never intercept events.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
