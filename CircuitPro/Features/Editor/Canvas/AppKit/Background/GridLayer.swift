import AppKit

class GridLayer: BaseGridLayer {

    private let baseLineWidth: CGFloat = 0.5      // …≈½ screen-point
    var lineWidth: CGFloat = 0.5 {
        didSet {
            setNeedsDisplay()
        }
    }

    // scale-aware update
    override func updateForMagnification() {
        super.updateForMagnification()             // keeps axisLineWidth in sync
        lineWidth = baseLineWidth / magnification
    }

    override func draw(in ctx: CGContext) {
        let spacing = adjustedSpacing()          // ← shared logic
        let tile    = ctx.boundingBoxOfClipPath

        let startI = Int(floor((tile.minX - centerX) / spacing))
        let endI = Int(ceil((tile.maxX - centerX) / spacing))
        let startJ = Int(floor((tile.minY - centerY) / spacing))
        let endJ = Int(ceil((tile.maxY - centerY) / spacing))

        ctx.setShouldAntialias(true)

        // verticals
        for i in startI...endI {
            let x = centerX + CGFloat(i) * spacing
            if showAxes && i == 0 { continue }

            let isMajor = i % majorEvery == 0
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(NSColor.gray
                .withAlphaComponent(isMajor ? 0.30 : 0.15).cgColor)
            ctx.beginPath()
            ctx.move(to: .init(x: x, y: tile.minY))
            ctx.addLine(to: .init(x: x, y: tile.maxY))
            ctx.strokePath()
        }

        // horizontals
        for j in startJ...endJ {
            let y = centerY + CGFloat(j) * spacing
            if showAxes && j == 0 { continue }

            let isMajor = j % majorEvery == 0
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(NSColor.gray
                .withAlphaComponent(isMajor ? 0.30 : 0.15).cgColor)
            ctx.beginPath()
            ctx.move(to: .init(x: tile.minX, y: y))
            ctx.addLine(to: .init(x: tile.maxX, y: y))
            ctx.strokePath()
        }

        drawAxes(in: ctx, tileRect: tile)
    }
}
