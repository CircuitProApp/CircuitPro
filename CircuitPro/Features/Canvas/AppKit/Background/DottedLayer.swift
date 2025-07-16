//  Features/Canvas/AppKit/Background/DottedLayer.swift
import AppKit
import CoreGraphics

final class DottedLayer: BaseGridLayer {

    // 1. Radii
    private let baseDotRadius: CGFloat = 1
    private(set) var dotRadius: CGFloat = 1

    // 1.1 React to zoom
    override func updateForMagnification() {
        super.updateForMagnification()
        dotRadius = baseDotRadius / max(magnification, 1)
        setNeedsDisplay()
    }

    // 2. Paint one CATiledLayer tile
    override func draw(in ctx: CGContext) {
        let spacing = adjustedSpacing()
        let r       = dotRadius
        let tile    = ctx.boundingBoxOfClipPath

        // colour constants (device-gray = thread-safe)
        ctx.setAllowsAntialiasing(false)
        let major = CGColor(gray: 0.5, alpha: 0.7)
        let minor = CGColor(gray: 0.5, alpha: 0.3)

        // 2.1 iterate only over dots that can fall into this tile
        let startX = floor(tile.minX / spacing)
        let endX   = ceil(tile.maxX / spacing)
        let startY = floor(tile.minY / spacing)
        let endY   = ceil(tile.maxY / spacing)

        for i in Int(startX)...Int(endX) {
            let x = CGFloat(i) * spacing + spacing * 0.5
            for j in Int(startY)...Int(endY) {
                let y = CGFloat(j) * spacing + spacing * 0.5
                if !tile.intersects(CGRect(x: x - r, y: y - r,
                                           width: r * 2, height: r * 2)) { continue }
                ctx.setFillColor((i % majorEvery == 0 || j % majorEvery == 0) ? major : minor)
                ctx.fillEllipse(in: .init(x: x - r, y: y - r,
                                          width: r * 2, height: r * 2))
            }
        }

        ctx.setAllowsAntialiasing(true)
        drawAxes(in: ctx, tileRect: tile)
    }
}
