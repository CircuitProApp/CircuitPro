import AppKit
import CoreGraphics

/// Optimised dotted-grid layer that aligns perfectly with the axes and
/// uses a cached CGPattern so scrolling costs ~0 CPU.
final class DottedLayer: BaseGridLayer {

    // MARK: – Public knobs (same as before)
    private let baseDotRadius: CGFloat = 1
    private(set) var dotRadius: CGFloat = 1 { didSet { invalidatePattern() } }

    // MARK: – Pattern cache & book-keeping
    private var cachedPattern: CGPattern?
    private var cachedSpacing: CGFloat  = .nan
    private var cachedDotRadius: CGFloat = .nan
    private var cachedMajorEvery: Int    = -1
    private let patternCS = CGColorSpace(patternBaseSpace: nil)!

    // MARK: – React to zoom
    override func updateForMagnification() {
        super.updateForMagnification()
        dotRadius = baseDotRadius / max(magnification, 1)
    }

    // MARK: – Main draw entry
    override func draw(in ctx: CGContext) {
        let spacing = adjustedSpacing()

        // 1. Re-build pattern only if geometry really changed
        if cachedPattern == nil ||
           spacing      != cachedSpacing ||
           dotRadius    != cachedDotRadius ||
           majorEvery   != cachedMajorEvery {

            cachedPattern    = buildPattern(spacing: spacing, radius: dotRadius)
            cachedSpacing    = spacing
            cachedDotRadius  = dotRadius
            cachedMajorEvery = majorEvery
        }

        guard let pattern = cachedPattern else { return }

        // 2. ALIGN the pattern so a dot sits exactly on the logical axes
        //
        //    Quartz places the pattern cell’s origin at `phase`.
        //    We want world-coordinate (centerX, centerY) to line up with
        //    the *centre* of a minor cell (spacing · 0.5).
        //
        //    phase = remainder − 0.5 · spacing
        let remX = centerX.truncatingRemainder(dividingBy: spacing)
        let remY = centerY.truncatingRemainder(dividingBy: spacing)
        ctx.setPatternPhase(CGSize(width: remX - spacing * 0.5,
                                   height: remY - spacing * 0.5))

        // 3. Pattern fill (AA off – a one-dot texture doesn’t need it)
        var alpha: CGFloat = 1
        ctx.setAllowsAntialiasing(false)
        ctx.setShouldAntialias(false)
        ctx.setFillColorSpace(patternCS)
        ctx.setFillPattern(pattern, colorComponents: &alpha)
        ctx.fill(ctx.boundingBoxOfClipPath)

        // 4. Draw axes on top (AA back on)
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        drawAxes(in: ctx, tileRect: ctx.boundingBoxOfClipPath)
    }

    // MARK: – Pattern builder (runs rarely)
    private func buildPattern(spacing: CGFloat,
                              radius: CGFloat) -> CGPattern? {

        let cellSide = spacing * CGFloat(majorEvery)
        let cellRect = CGRect(origin: .zero,
                              size: CGSize(width: cellSide, height: cellSide))

        // >>> Needs an `AnyObject` for Unmanaged
        final class Capture: NSObject {
            let s: CGFloat; let r: CGFloat; let N: Int
            init(s: CGFloat, r: CGFloat, N: Int) { self.s = s; self.r = r; self.N = N }
        }
        let cap = Capture(s: spacing, r: radius, N: majorEvery)
        let ip  = Unmanaged.passRetained(cap).toOpaque()

        var cbs = CGPatternCallbacks(
            version: 0,
            drawPattern: { info, ctx in
                let c = Unmanaged<Capture>.fromOpaque(info!).takeUnretainedValue()
                let (s, r, N) = (c.s, c.r, c.N)

                for i in 0..<N {
                    let cx = CGFloat(i) * s + s * 0.5
                    for j in 0..<N {
                        let cy = CGFloat(j) * s + s * 0.5
                        let isMajor = (i == 0) || (j == 0)   // i % N == 0 simplifies to i == 0
                        ctx.setFillColor(gray: 0.5,            // 0.5 = 50 % gray
                                         alpha: isMajor ? 0.7 : 0.3)
                        ctx.fillEllipse(in: CGRect(x: cx - r,
                                                   y: cy - r,
                                                   width: r * 2,
                                                   height: r * 2))
                    }
                }
            },
            releaseInfo: { info in
                Unmanaged<AnyObject>.fromOpaque(info!).release()
            })

        return CGPattern(info: ip,
                         bounds: cellRect,
                         matrix: .identity,
                         xStep: cellSide,
                         yStep: cellSide,
                         tiling: .constantSpacing,
                         isColored: true,
                         callbacks: &cbs)
    }

    private func invalidatePattern() { cachedPattern = nil }
}
