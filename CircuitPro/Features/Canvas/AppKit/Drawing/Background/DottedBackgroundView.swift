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
        let startX = floor(rect.minX / spacing) * spacing
        let startY = floor(rect.minY / spacing) * spacing

        var y = startY
        while y <= rect.maxY {
            var x = startX
            while x <= rect.maxX {
                let xGridIndex = (x / spacing).rounded()
                let yGridIndex = (y / spacing).rounded()

                let isMajor = xGridIndex.truncatingRemainder(dividingBy: 10) == 0 ||
                              yGridIndex.truncatingRemainder(dividingBy: 10) == 0

                ctx.setFillColor(isMajor ? majorColor : minorColor)
                ctx.fillEllipse(in: CGRect(x: x - radius,
                                           y: y - radius,
                                           width:  radius * 2,       // diameter (fixed)
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
        tileLayer.tileSize       = CGSize(width: 256, height: 256)   // NEW – bigger tile
        tileLayer.levelsOfDetail = 4                                 // NEW – down-scales
        tileLayer.levelsOfDetailBias = 4                             // NEW – up-scales
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
