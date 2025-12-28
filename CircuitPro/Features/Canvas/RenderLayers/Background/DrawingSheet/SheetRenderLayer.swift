import AppKit

final class SheetRenderLayer: RenderLayer {
    // Persistent container for all sheet sublayers.
    private let rootLayer = CALayer()

    // Renderer constants.
    private let inset: CGFloat = 20
    private let cellHeight: CGFloat = 25
    private let cellPad: CGFloat = 10
    private let unitsPerMM: CGFloat = 10

    // Baked-in title block values (insertion order preserved in Swift dictionaries).
    private let bakedCellValues: [String: String] = [
        "Unit": "mm"
    ]

    func install(on hostLayer: CALayer) {
        rootLayer.contentsScale = hostLayer.contentsScale
        hostLayer.addSublayer(rootLayer)
    }

    func update(using context: RenderContext) {
        let newLayers = createSheetLayers(context: context)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rootLayer.sublayers = newLayers
        CATransaction.commit()
    }

    // MARK: - Building the layer tree

    private func createSheetLayers(context: RenderContext) -> [CALayer] {
        var generated: [CALayer] = []

        let hSpacing = 10 * unitsPerMM
        let vSpacing = 10 * unitsPerMM

        let metrics = DrawingMetrics(
            viewBounds: context.hostViewBounds,
            inset: inset,
            horizontalTickSpacing: hSpacing,
            verticalTickSpacing: vSpacing,
            cellHeight: cellHeight,
            cellValues: bakedCellValues
        )

        let backgroundColor = context.environment.canvasTheme.backgroundColor
        generated.append(
            contentsOf: createBackgroundLayers(metrics: metrics, backgroundColor: backgroundColor))
        let markerColor =
            NSColor(cgColor: context.environment.canvasTheme.sheetMarkerColor) ?? .black
        generated.append(
            contentsOf: BorderDrawer().makeLayers(metrics: metrics, lineColor: markerColor.cgColor))

        if !bakedCellValues.isEmpty {
            let drawer = TitleBlockDrawer(
                cellValues: bakedCellValues,
                lineColor: markerColor,
                textColor: markerColor,
                cellPad: cellPad,
                cellHeight: cellHeight,
                safeFont: safeFont
            )
            generated.append(contentsOf: drawer.makeLayers(metrics: metrics))
        }

        for position in [RulerDrawer.Position.top, .bottom, .left, .right] {
            let drawer = RulerDrawer(
                position: position,
                lineColor: markerColor,
                textColor: markerColor,
                safeFont: safeFont,
                showLabels: true
            )
            generated.append(contentsOf: drawer.makeLayers(metrics: metrics))
        }

        return generated
    }

    private func createBackgroundLayers(metrics: DrawingMetrics, backgroundColor: CGColor)
        -> [CALayer]
    {
        let rulerBGPath = CGMutablePath()
        rulerBGPath.addRect(metrics.outerBounds)
        rulerBGPath.addRect(metrics.innerBounds)

        let rulerBGLayer = CAShapeLayer()
        rulerBGLayer.path = rulerBGPath
        rulerBGLayer.fillRule = .evenOdd
        rulerBGLayer.fillColor = backgroundColor

        var layers: [CALayer] = [rulerBGLayer]

        if metrics.titleBlockFrame.height > 0 {
            let titleBGLayer = CAShapeLayer()
            titleBGLayer.path = CGPath(rect: metrics.titleBlockFrame, transform: nil)
            titleBGLayer.fillColor = backgroundColor
            layers.append(titleBGLayer)
        }

        return layers
    }

    private func safeFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        if #available(macOS 11.0, *) {
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }
}
