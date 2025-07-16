//  Features/Canvas/AppKit/Background/GridLayer.swift
import AppKit
import CoreGraphics

final class GridLayer: BaseGridLayer {

    // 1. Line width
    private let baseLineWidth: CGFloat = 0.5
    private(set) var lineWidth: CGFloat = 0.5

    override func updateForMagnification() {
        super.updateForMagnification()
        lineWidth = baseLineWidth / magnification
        setNeedsDisplay()
    }

    // 2. Paint one tile
    override func draw(in ctx: CGContext) {
        let spacing = adjustedSpacing()
        let lw      = lineWidth
        let tile    = ctx.boundingBoxOfClipPath

        ctx.setAllowsAntialiasing(false)
        let major = CGColor(gray: 0.6, alpha: 0.30)
        let minor = CGColor(gray: 0.6, alpha: 0.15)

        // vertical lines
        let startX = floor(tile.minX / spacing)
        let endX   = ceil(tile.maxX / spacing)
        for i in Int(startX)...Int(endX) {
            let x = CGFloat(i) * spacing
            ctx.setFillColor(i % majorEvery == 0 ? major : minor)
            ctx.fill(CGRect(x: x - lw * 0.5, y: tile.minY,
                            width: lw, height: tile.height))
        }

        // horizontal lines
        let startY = floor(tile.minY / spacing)
        let endY   = ceil(tile.maxY / spacing)
        for j in Int(startY)...Int(endY) {
            let y = CGFloat(j) * spacing
            ctx.setFillColor(j % majorEvery == 0 ? major : minor)
            ctx.fill(CGRect(x: tile.minX, y: y - lw * 0.5,
                            width: tile.width, height: lw))
        }

        ctx.setAllowsAntialiasing(true)
        drawAxes(in: ctx, tileRect: tile)
    }
}
