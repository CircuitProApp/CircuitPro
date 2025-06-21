//
//  BackgroundView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/16/25.
//

import AppKit

final class BackgroundView: NSView {

    // MARK: - Public API

    var currentStyle: CanvasBackgroundStyle = .dotted {
        didSet { rebuildLayer() }
    }

    var showAxes: Bool = true {
        didSet {
            (tiledLayer as? BaseGridLayer)?.showAxes = showAxes
        }
    }

    /// in “canvas units” (10 units == 1 mm)
    var gridSpacing: CGFloat = 10 {
        didSet {
            (tiledLayer as? BaseGridLayer)?.unitSpacing = gridSpacing
        }
    }

    /// 1.0 == 100% zoom
    var magnification: CGFloat = 1.0 {
        didSet {
            (tiledLayer as? BaseGridLayer)?.magnification = magnification
        }
    }

    // MARK: - Private

    private var tiledLayer: CALayer?

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
        tiledLayer?.setNeedsDisplay()
    }

    private func rebuildLayer() {
        tiledLayer?.removeFromSuperlayer()

        // pick your style
        let layer: BaseGridLayer = {
            switch currentStyle {
            case .dotted:
                return DottedLayer()
            case .grid:
                return GridLayer()
            }
        }()

        // drive all visuals from these four:
        layer.unitSpacing    = gridSpacing
        layer.showAxes       = showAxes
        layer.axisLineWidth  = 1.0                   // base axis width
        layer.magnification  = magnification

        layer.frame = bounds
        layer.contentsScale = window?.backingScaleFactor
                          ?? NSScreen.main?.backingScaleFactor
                          ?? 2

        self.layer?.addSublayer(layer)
        self.tiledLayer = layer
    }
}
