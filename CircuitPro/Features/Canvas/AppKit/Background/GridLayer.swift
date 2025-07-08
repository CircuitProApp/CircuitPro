import AppKit            // only for BaseGridLayer & colour constants
import CoreGraphics

// MARK: - Thread-safe capture passed through `info`
private final class GridCapture {
    let spacing: CGFloat
    let lineWidth: CGFloat
    let majorEvery: Int
    let majorColor: CGColor
    let minorColor: CGColor

    init(spacing: CGFloat,
         lineWidth: CGFloat,
         majorEvery: Int) {

        self.spacing    = spacing
        self.lineWidth  = lineWidth
        self.majorEvery = majorEvery

        // Create CGColors ON THE MAIN THREAD (thread-safe afterwards)
        let graySpace = CGColorSpaceCreateDeviceGray()
        self.majorColor = CGColor(gray: 0.6, alpha: 0.30)
        self.minorColor = CGColor(gray: 0.6, alpha: 0.15)
    }
}

// MARK: - Optimised, thread-safe grid layer
final class GridLayer: BaseGridLayer {

    private let baseLineWidth: CGFloat = 0.5
    private(set) var lineWidth: CGFloat = 0.5 { didSet { invalidatePattern() } }

    private var pattern: CGPattern?
    private var cachedSpacing: CGFloat  = .nan
    private var cachedLineWidth: CGFloat = .nan
    private var cachedMajorEvery: Int    = -1
    private let patternCS = CGColorSpace(patternBaseSpace: nil)!

    // Scale-aware update
    override func updateForMagnification() {
        super.updateForMagnification()
        lineWidth = baseLineWidth / magnification
    }

    // Main draw
    override func draw(in ctx: CGContext) {
        let spacing = adjustedSpacing()

        if  pattern == nil ||
            spacing    != cachedSpacing ||
            lineWidth  != cachedLineWidth ||
            majorEvery != cachedMajorEvery {

            pattern         = buildPattern(spacing: spacing, lw: lineWidth)
            cachedSpacing   = spacing
            cachedLineWidth = lineWidth
            cachedMajorEvery = majorEvery
        }
        guard let pattern else { return }

        // Align the tiled pattern with logical axes
        ctx.setPatternPhase(.init(
            width:  centerX.truncatingRemainder(dividingBy: spacing),
            height: centerY.truncatingRemainder(dividingBy: spacing)))

        // Fill (AA off – texture copy only)
        var alpha: CGFloat = 1
        ctx.setShouldAntialias(false)
        ctx.setFillColorSpace(patternCS)
        ctx.setFillPattern(pattern, colorComponents: &alpha)
        ctx.fill(ctx.boundingBoxOfClipPath)

        // Draw axes on top
        ctx.setShouldAntialias(true)
        drawAxes(in: ctx, tileRect: ctx.boundingBoxOfClipPath)
    }

    // Build CGPattern – runs ONLY on main thread
    private func buildPattern(spacing: CGFloat,
                              lw: CGFloat) -> CGPattern? {

        let cellSide = spacing * CGFloat(majorEvery)
        let bounds   = CGRect(origin: .zero, size: .init(width: cellSide, height: cellSide))

        // Capture built once, lives until Core Graphics releases it
        let cap = GridCapture(spacing: spacing, lineWidth: lw, majorEvery: majorEvery)
        let info = Unmanaged.passRetained(cap).toOpaque()

        var cbs = CGPatternCallbacks(version: 0,
                                     drawPattern: GridLayer.drawPattern,
                                     releaseInfo: GridLayer.releaseInfo)

        return CGPattern(info: info,
                         bounds: bounds,
                         matrix: .identity,
                         xStep: cellSide,
                         yStep: cellSide,
                         tiling: .constantSpacing,
                         isColored: true,
                         callbacks: &cbs)
    }

    // Static, non-capturing C callbacks
    private static let drawPattern: CGPatternDrawPatternCallback = { info, ctx in
        guard let info else { return }
        let cap = Unmanaged<GridCapture>.fromOpaque(info).takeUnretainedValue()

        let s  = cap.spacing
        let lw = cap.lineWidth
        let N  = cap.majorEvery
        let cellSide = CGFloat(N) * s

        for i in 0...N {                      // includes cell edges (= majors)
            let offset = CGFloat(i) * s
            let colour = (i == 0) ? cap.majorColor : cap.minorColor
            ctx.setFillColor(colour)

            // vertical
            ctx.fill(CGRect(x: offset - lw * 0.5, y: 0,
                            width: lw, height: cellSide))
            // horizontal
            ctx.fill(CGRect(x: 0, y: offset - lw * 0.5,
                            width: cellSide, height: lw))
        }
    }

    private static let releaseInfo: CGPatternReleaseInfoCallback = { info in
        guard let info else { return }
        Unmanaged<AnyObject>.fromOpaque(info).release()   // pair with passRetained
    }

    private func invalidatePattern() { pattern = nil }
}
