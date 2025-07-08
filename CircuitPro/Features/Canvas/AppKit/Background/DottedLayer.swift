import AppKit

class DottedLayer: BaseGridLayer {
    private let baseDotRadius: CGFloat = 1
    private var dotRadius: CGFloat = 1 {
        didSet { invalidatePattern() }
    }

    private var patternColor: CGColor?
    private var patternSpacing: CGFloat = 0

    // Update zoom-dependent parameters
    override func updateForMagnification() {
        super.updateForMagnification()
        dotRadius = baseDotRadius / max(magnification, 1)
    }

    private func invalidatePattern() {
        patternColor = nil
        setNeedsDisplay()
    }

    override var unitSpacing: CGFloat {
        get { super.unitSpacing }
        set { super.unitSpacing = newValue; invalidatePattern() }
    }

    override var majorEvery: Int {
        get { super.majorEvery }
        set { super.majorEvery = newValue; invalidatePattern() }
    }

    override var showAxes: Bool {
        get { super.showAxes }
        set { super.showAxes = newValue; invalidatePattern() }
    }

    // Draw a single tile
    override func draw(in ctx: CGContext) {
        let spacing = adjustedSpacing()

        if patternColor == nil || patternSpacing != spacing {
            DispatchQueue.main.sync {
                rebuildPattern(spacing: spacing)
            }
        }

        guard let patternColor else { return }

        let tileRect = ctx.boundingBoxOfClipPath

        ctx.setFillColor(patternColor)
        ctx.setPatternPhase(CGSize(width: centerX, height: centerY))
        ctx.fill(tileRect)

        drawAxes(in: ctx, tileRect: tileRect)
    }

    private func rebuildPattern(spacing: CGFloat) {
        patternSpacing = spacing
        let tileSize = spacing * CGFloat(majorEvery)
        let width  = Int(ceil(tileSize))
        let height = Int(ceil(tileSize))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        for i in 0..<majorEvery {
            let pointX = CGFloat(i) * spacing + spacing / 2
            for j in 0..<majorEvery {
                if showAxes && (i == 0 || j == 0) { continue }
                let pointY = CGFloat(j) * spacing + spacing / 2
                let isMajor = (i == 0 || j == 0)
                let alpha: CGFloat = isMajor ? 0.7 : 0.3
                context.setFillColor(NSColor.gray.withAlphaComponent(alpha).cgColor)
                context.fillEllipse(in: CGRect(
                    x: pointX - dotRadius,
                    y: pointY - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                ))
            }
        }

        guard let image = context.makeImage() else { return }

        patternColor = NSColor(patternImage: NSImage(cgImage: image, size: .init(width: tileSize, height: tileSize))).cgColor
    }
}
