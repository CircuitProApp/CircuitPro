// CircuitPro/Features/Canvas/AppKit/Drawing/Background/DottedBackgroundView.swift
import AppKit
import QuartzCore

// ─────────────────────────────────────────────────────────
// 1. The tile-drawing layer
// ─────────────────────────────────────────────────────────
final class DotTileLayer: CATiledLayer {

    // MARK: – Public knobs
    var unitSpacing:    CGFloat = 10.0 { didSet { setNeedsDisplay() } }

    /// Current canvas magnification (1 = 100 %)
    var magnification:  CGFloat = 1.0 {
        didSet {                                          // NEW
            guard magnification != oldValue else { return }
            updateForMagnification()                      // NEW
            setNeedsDisplay()                             // NEW
        }
    }

    // MARK: – Dot radius bookkeeping (NEW)
    private let baseDotRadius: CGFloat = 1               // logical radius at 100 %
    private var dotRadius:     CGFloat = 1               // cached, in *screen* points

    private func updateForMagnification() {              // NEW
        // Make the dot shrink as you zoom-in so its *logical* size is fixed.
        // If you prefer constant on-screen size, replace “/” with “*”.
        dotRadius = baseDotRadius / max(magnification, 1)
    }

    // MARK: – Helpers
    /// Returns the first multiple of `step` that is **≤ value**.
    /// Using this instead of `floor(value / step) * step` avoids a costly
    /// division for every grid intersection.
    private func previousMultiple(of step: CGFloat, beforeOrEqualTo value: CGFloat) -> CGFloat {
        let quotient = Int(value / step)
        return CGFloat(quotient) * step
    }

    // Eliminate cross-fade when new tiles appear
    override class func fadeDuration() -> CFTimeInterval { 0 }

    // Draw just the dots that fall inside `ctx.boundingBoxOfClipPath`
    override func draw(in ctx: CGContext) {
        let spacing     = adjustedSpacing()
        let radius      = dotRadius                         // NEW
        let minorColor  = NSColor.gray.withAlphaComponent(0.5).cgColor
        let majorColor  = NSColor.gray.withAlphaComponent(1).cgColor

        let rect = ctx.boundingBoxOfClipPath

        // Start at the first grid intersection **before** this tile
        // Find the first grid intersection *before* the tile. Doing the maths with
        // integers is noticeably cheaper than floating-point `floor` for the
        // thousands of times this method gets called while scrolling/zooming.
        let startX = previousMultiple(of: spacing, beforeOrEqualTo: rect.minX)
        let startY = previousMultiple(of: spacing, beforeOrEqualTo: rect.minY)

        var y = startY
        let maxY = rect.maxY
        let maxX = rect.maxX

        while y <= maxY {
            var x = startX

            // Calculate the row’s Y index once per row instead of per-dot
            let yGridIndex = Int(round(y / spacing))
            let yIsMajor   = yGridIndex % 10 == 0

            while x <= maxX {
                // Re-use the *integer* modulus to decide major/minor dots – much faster
                let xGridIndex = Int(round(x / spacing))
                let isMajor = yIsMajor || xGridIndex % 10 == 0

                ctx.setFillColor(isMajor ? majorColor : minorColor)
                ctx.fillEllipse(in: CGRect(x: x - radius,
                                           y: y - radius,
                                           width:  radius * 2,
                                           height: radius * 2))
                x += spacing
            }
            y += spacing
        }
    }

    // Grid-spacing rules (unchanged)
    func adjustedSpacing() -> CGFloat {
        switch unitSpacing {
        case 5:   return magnification < 2.0  ? 10 : 5               // 0.5 mm grid
        case 2.5: // 0.25 mm grid
            if magnification < 2.0 {
                return 10
            } else if magnification < 3.0 {
                return 5
            } else {
                return 2.5
            }
        case 1:   // 0.1 mm grid
            if magnification < 2.5 {
                return 8
            } else if magnification < 5.0 {
                return 4
            } else if magnification < 10 {
                return 2
            } else {
                return 1
            }
        default: return unitSpacing
        }
    }
}

// ─────────────────────────────────────────────────────────
// 2. A view backed by that layer
// ─────────────────────────────────────────────────────────
final class DottedBackgroundView: NSView {

    // Public knobs
    var unitSpacing: CGFloat = 10.0 {
        didSet {
            (layer as? DotTileLayer)?.unitSpacing = unitSpacing
            layer?.setNeedsDisplay()
        }
    }

    var magnification: CGFloat = 1.0 {
        didSet {
            (layer as? DotTileLayer)?.magnification = magnification
            layer?.setNeedsDisplay()
        }
    }

    /// Tell AppKit we want a custom backing layer
    override func makeBackingLayer() -> CALayer {
        let tileLayer            = DotTileLayer()
        tileLayer.unitSpacing    = unitSpacing
        tileLayer.magnification  = magnification
        // Use larger tiles so fewer need to be generated while scrolling.
        // A power-of-two keeps Core Animation happy.
        tileLayer.tileSize           = CGSize(width: 512, height: 512)

        // Enable asynchronous drawing so heavy grid generation doesn’t
        // block the main thread while the user is scrolling/zooming.
        tileLayer.drawsAsynchronously = true

        tileLayer.levelsOfDetail      = 4  // down-scale quality levels
        tileLayer.levelsOfDetailBias  = 4  // up-scale quality levels
        tileLayer.frame          = CGRect(x: 0, y: 0,
                                          width: 5_000, height: 5_000)
        return tileLayer
    }

    /// Keep the 5 000 × 5 000 layer centred as the view resizes
    override func layout() {
        super.layout()
        guard let tileLayer = layer else { return }
        tileLayer.position    = CGPoint(x: bounds.midX, y: bounds.midY)
        tileLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }
}
