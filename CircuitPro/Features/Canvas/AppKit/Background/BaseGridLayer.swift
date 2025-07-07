import AppKit

class BaseGridLayer: CATiledLayer {

    // MARK: - Public knobs
    var unitSpacing: CGFloat = 10 { didSet { setNeedsDisplay() } }
    var majorEvery: Int = 10
    var showAxes: Bool = true { didSet { setNeedsDisplay() } }
    var axisLineWidth: CGFloat = 1 { didSet { setNeedsDisplay() } }
    var magnification: CGFloat = 1.0 { didSet { updateForMagnification(); setNeedsDisplay() } }

    // MARK: - Internal constants
    private let baseAxisLineWidth: CGFloat = 1.0
    let centerX: CGFloat = 2_500
    let centerY: CGFloat = 2_500

    // MARK: - Init boiler-plate
    override class func fadeDuration() -> CFTimeInterval { 0 }

    private func commonInit() {
        tileSize          = .init(width: 512, height: 512)
        levelsOfDetail    = 4
        levelsOfDetailBias = 4
    }

    override init() {
        super.init()
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    // ❶ The missing copy initialiser
    override required init(layer: Any) {
        super.init(layer: layer)

        // copy properties from the source layer
        if let source = layer as? BaseGridLayer {
            unitSpacing   = source.unitSpacing
            majorEvery    = source.majorEvery
            showAxes      = source.showAxes
            axisLineWidth = source.axisLineWidth
            magnification = source.magnification
        }
        // nothing to do for commonInit(): the layer we are copying
        // already has its tileSize, levelsOfDetail, … set up
    }

    // MARK: – Zoom hook
    func updateForMagnification() { axisLineWidth = baseAxisLineWidth / magnification }

    // MARK: – Shared spacing logic (your exact rules)
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

    // MARK: – Axis drawing (unchanged)
    func drawAxes(in ctx: CGContext, tileRect: CGRect) {
        guard showAxes else { return }

        ctx.setLineWidth(axisLineWidth)
        let half = axisLineWidth / 2

        // Y
        if tileRect.intersects(
            .init(x: centerX-half, y: tileRect.minY, width: axisLineWidth, height: tileRect.height)
        ) {
            ctx.setStrokeColor(NSColor.systemGreen.withAlphaComponent(0.75).cgColor)
            ctx.beginPath()
            ctx.move(to: .init(x: centerX, y: tileRect.minY))
            ctx.addLine(to: .init(x: centerX, y: tileRect.maxY))
            ctx.strokePath()
        }

        // X
        if tileRect.intersects(
            .init(x: tileRect.minX, y: centerY-half, width: tileRect.width, height: axisLineWidth)
        ) {
            ctx.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.75).cgColor)
            ctx.beginPath()
            ctx.move(to: .init(x: tileRect.minX, y: centerY))
            ctx.addLine(to: .init(x: tileRect.maxX, y: centerY))
            ctx.strokePath()
        }
    }
}
