import AppKit
import QuartzCore

// ─────────────────────────────────────────────────────────
// 1. The tile-drawing layer
// ─────────────────────────────────────────────────────────
final class DotTileLayer: CATiledLayer {

    /// Eliminate cross-fade when new tiles appear.
    override class func fadeDuration() -> CFTimeInterval { 0 }

    /// Draw just the dots that fall inside `ctx.boundingBoxOfClipPath`.
    override func draw(in ctx: CGContext) {
        let spacing: CGFloat    = 10          // dot pitch
        let radius:  CGFloat    = 1
        ctx.setFillColor(NSColor(.gray.opacity(0.5)).cgColor)

        let rect = ctx.boundingBoxOfClipPath

        // Start at the first grid intersection **before** this tile.
        let startX = floor(rect.minX / spacing) * spacing
        let startY = floor(rect.minY / spacing) * spacing

        var y = startY
        while y <= rect.maxY {
            var x = startX
            while x <= rect.maxX {
                ctx.fillEllipse(in: CGRect(x: x - radius,
                                           y: y - radius,
                                           width: radius,
                                           height: radius))
                x += spacing
            }
            y += spacing
        }
    }
}

// ─────────────────────────────────────────────────────────
// 2. A view backed by that layer
// ─────────────────────────────────────────────────────────
final class DottedBackgroundView: NSView {

    /// Tell AppKit we want a custom backing layer.
    override func makeBackingLayer() -> CALayer {
        let tileLayer            = DotTileLayer()
        tileLayer.tileSize       = CGSize(width: 256, height: 256)   // tune if needed
        tileLayer.levelsOfDetail = 1                                 // no mip-maps
        tileLayer.frame          = CGRect(x: 0, y: 0,
                                          width: 5_000, height: 5_000)
        return tileLayer
    }

    // Keep the 5 000 × 5 000 layer centred as the view resizes.
    override func layout() {
        super.layout()
        guard let tileLayer = layer else { return }
        tileLayer.position    = CGPoint(x: bounds.midX, y: bounds.midY)
        tileLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }
}
