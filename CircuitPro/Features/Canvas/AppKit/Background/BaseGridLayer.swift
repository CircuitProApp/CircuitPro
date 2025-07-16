// CircuitPro/Features/Canvas/AppKit/Background/BaseGridLayer.swift
import AppKit

class BaseGridLayer: CATiledLayer {

    // 1. Public knobs
    var unitSpacing: CGFloat = 10     { didSet { invalidatePatterns() } }
    var majorEvery: Int      = 10     { didSet { invalidatePatterns() } }
    var showAxes: Bool       = true   { didSet { setNeedsDisplay() } }
    var axisLineWidth: CGFloat = 1    { didSet { setNeedsDisplay() } }
    var magnification: CGFloat = 1.0  { didSet { updateForMagnification() } }
    override class func fadeDuration() -> CFTimeInterval { 0 }

    // 2. Axis constants (logical board centre)
    let centerX: CGFloat = 2_500
    let centerY: CGFloat = 2_500

    // 3. Init
    override init() {
        super.init()
        tileSize          = .init(width: 512, height: 512)
        levelsOfDetail     = 4
        levelsOfDetailBias = 4
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        tileSize          = .init(width: 512, height: 512)
        levelsOfDetail     = 4
        levelsOfDetailBias = 4
    }

    // 4. Copy-initialiser
    override init(layer: Any) {
        if let src = layer as? BaseGridLayer {
            unitSpacing   = src.unitSpacing
            majorEvery    = src.majorEvery
            showAxes      = src.showAxes
            axisLineWidth = src.axisLineWidth
            magnification = src.magnification
        }
        super.init(layer: layer)
    }
    
    // add to BaseGridLayer just below invalidatePatterns()
    func adjustedSpacing() -> CGFloat {
        switch unitSpacing {
        case 5:   return magnification < 2.0  ? 10 : 5               // 0.5 mm grid
        case 2.5: // 0.25 mm grid
            if magnification < 2.0 { return 10 }
            if magnification < 3.0 { return 5 }
            return 2.5
        case 1:   // 0.1 mm grid
            if magnification < 2.5 { return 8 }
            if magnification < 5.0 { return 4 }
            if magnification < 10  { return 2 }
            return 1
        default:  return unitSpacing
        }
    }

    // 5. Zoom hook
    func updateForMagnification() { axisLineWidth = 1.0 / magnification }

    // 6. Pattern cache hook
    func invalidatePatterns()     { setNeedsDisplay() }

    // 7. Axis drawing used by the subclasses
    func drawAxes(in ctx: CGContext, tileRect: CGRect) {
        guard showAxes else { return }

        let lw = axisLineWidth
        ctx.setLineWidth(lw)

        // Y axis
        if tileRect.intersects(CGRect(x: centerX - lw * 0.5,
                                      y: tileRect.minY,
                                      width: lw,
                                      height: tileRect.height)) {
            ctx.setStrokeColor(NSColor.systemGreen.withAlphaComponent(0.75).cgColor)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: centerX, y: tileRect.minY))
            ctx.addLine(to: CGPoint(x: centerX, y: tileRect.maxY))
            ctx.strokePath()
        }

        // X axis
        if tileRect.intersects(CGRect(x: tileRect.minX,
                                      y: centerY - lw * 0.5,
                                      width: tileRect.width,
                                      height: lw)) {
            ctx.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.75).cgColor)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: tileRect.minX, y: centerY))
            ctx.addLine(to: CGPoint(x: tileRect.maxX, y: centerY))
            ctx.strokePath()
        }
    }
}
