// CircuitPro/Features/Canvas/AppKit/Drawing/Background/DottedBackgroundView.swift
import AppKit

final class DottedBackgroundView: NSView, CALayerDelegate {

    // MARK: - Public Properties
    var unitSpacing: CGFloat = 10.0 {
        didSet { layer?.setNeedsDisplay() }
    }

    var magnification: CGFloat = 1.0 {
        didSet { layer?.setNeedsDisplay() }
    }

    // MARK: - View Lifecycle & Configuration
    
    // Programmatic initializer
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    // Storyboard/XIB initializer
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    // A single setup method called by both initializers.
    private func commonInit() {
        self.wantsLayer = true
        // Set the layer's delegate immediately during initialization.
        self.layer?.delegate = self
    }

    override var wantsUpdateLayer: Bool { true }

    // MARK: - Drawing Logic
    
    // This is called when the layer needs to update, but before drawing.
    // We use it to set high-level properties.
    override func updateLayer() {
        guard let layer = self.layer else { return }
        layer.backgroundColor = NSColor.clear.cgColor
        layer.contentsScale = self.window?.backingScaleFactor ?? 1.0
    }
    
    // This delegate method performs the actual drawing.
    func draw(_ layer: CALayer, in ctx: CGContext) {
        // We always draw within the view's visible rectangle.
        let visibleRect = self.visibleRect

        let spacing = adjustedSpacing()
        let dotRadius = (1.0 / max(magnification, 1.0))
        
        let minorColor = NSColor.gray.withAlphaComponent(0.5).cgColor
        let majorColor = NSColor.gray.withAlphaComponent(1.0).cgColor

        let startX = previousMultiple(of: spacing, beforeOrEqualTo: visibleRect.minX)
        let startY = previousMultiple(of: spacing, beforeOrEqualTo: visibleRect.minY)

        var currentY = startY
        while currentY <= visibleRect.maxY {
            let yGridIndex = Int(round(currentY / spacing))
            let yIsMajor = (yGridIndex % 10 == 0)

            var currentX = startX
            while currentX <= visibleRect.maxX {
                let xGridIndex = Int(round(currentX / spacing))
                let isMajor = yIsMajor || (xGridIndex % 10 == 0)

                // Set color and draw the dot immediately.
                // This is the absolute cheapest way in terms of memory.
                ctx.setFillColor(isMajor ? majorColor : minorColor)
                let dotRect = CGRect(x: currentX - dotRadius, y: currentY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                ctx.fill(dotRect)

                currentX += spacing
            }
            currentY += spacing
        }
    }


    // MARK: - Helpers
    private func previousMultiple(of step: CGFloat, beforeOrEqualTo value: CGFloat) -> CGFloat {
        let quotient = Int(value / step)
        return CGFloat(quotient) * step
    }

    private func adjustedSpacing() -> CGFloat {
        switch unitSpacing {
        case 5:   return magnification < 2.0  ? 10 : 5
        case 2.5:
            if magnification < 2.0 { return 10 }
            else if magnification < 3.0 { return 5 }
            else { return 2.5 }
        case 1:
            if magnification < 2.5 { return 8 }
            else if magnification < 5.0 { return 4 }
            else if magnification < 10 { return 2 }
            else { return 1 }
        default: return unitSpacing
        }
    }
}
