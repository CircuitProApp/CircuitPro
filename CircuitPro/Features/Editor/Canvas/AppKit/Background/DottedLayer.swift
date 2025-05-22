import AppKit

class DottedLayer: BaseGridLayer {
    private let baseDotRadius: CGFloat = 1
    private var dotRadius: CGFloat = 1 {
        didSet { setNeedsDisplay() }
    }

    // Update zoom-dependent parameters
    override func updateForMagnification() {
        super.updateForMagnification()
        dotRadius = baseDotRadius / max(magnification, 1)
    }

    // Draw a single tile
    override func draw(in ctx: CGContext) {
        let spacing = adjustedSpacing()
        let radius = dotRadius
        let tileRect = ctx.boundingBoxOfClipPath

        let startI = Int(floor((tileRect.minX - centerX) / spacing))
        let endI = Int(ceil((tileRect.maxX - centerX) / spacing))
        let startJ = Int(floor((tileRect.minY - centerY) / spacing))
        let endJ = Int(ceil((tileRect.maxY - centerY) / spacing))

        for i in startI...endI {
            let pointX = centerX + CGFloat(i) * spacing

            for j in startJ...endJ {
                let pointY = centerY + CGFloat(j) * spacing

                if showAxes && (i == 0 || j == 0) {
                    continue
                }

                let isMajor = (i % majorEvery == 0) || (j % majorEvery == 0)
                let alpha = isMajor ? 0.7 : 0.3
                let color = NSColor.gray.withAlphaComponent(alpha).cgColor

                ctx.setFillColor(color)
                ctx.fillEllipse(in: CGRect(
                    x: pointX - radius,
                    y: pointY - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
        }

        drawAxes(in: ctx, tileRect: tileRect)
    }
}
