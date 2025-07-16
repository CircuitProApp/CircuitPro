import AppKit

final class BackgroundView: NSView {

    var currentStyle: CanvasBackgroundStyle = .dotted {
        didSet { rebuildLayer() }
    }
    var showAxes: Bool = true {
        didSet { (tiledLayer as? BaseGridLayer)?.showAxes = showAxes }
    }
    var gridSpacing: CGFloat = 10 {
        didSet { (tiledLayer as? BaseGridLayer)?.unitSpacing = gridSpacing }
    }
    var magnification: CGFloat = 1.0 {
        didSet { (tiledLayer as? BaseGridLayer)?.magnification = magnification }
    }

    private weak var tiledLayer: CALayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        rebuildLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        rebuildLayer()
    }

    override func layout() {
        super.layout()
        tiledLayer?.frame = bounds
        // NO setNeedsDisplay() here – scrolling alone never dirties a CATiledLayer
    }

    private func rebuildLayer() {
        tiledLayer?.removeFromSuperlayer()

        let layer: BaseGridLayer = {
            switch currentStyle {
            case .dotted: return DottedLayer()
            case .grid:   return GridLayer()
            }
        }()

        layer.unitSpacing   = gridSpacing
        layer.showAxes      = showAxes
        layer.axisLineWidth = 1.0
        layer.magnification = magnification
        layer.frame         = bounds
        layer.contentsScale = window?.backingScaleFactor
                           ?? NSScreen.main?.backingScaleFactor
                           ?? 2

        self.layer?.addSublayer(layer)
        self.tiledLayer = layer
    }
}
