import AppKit

class SheetRenderLayer: RenderLayer {
    var layerKey: String = "sheet"
    
    // 1. A single, persistent container layer for all sheet components.
    private let rootLayer = CALayer()
    
    // Constants can remain as properties of the renderer.
    private let graphicColor: NSColor = .black
    private let inset: CGFloat = 20
    private let cellHeight: CGFloat = 25
    private let cellPad: CGFloat = 10
    private let unitsPerMM: CGFloat = 10
    
    /// **NEW:** Called once to install the root container layer.
    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(rootLayer)
    }

    /// **NEW:** Rebuilds the sheet's sublayer tree in memory and atomically replaces the
    /// existing tree. This is highly efficient for semi-static content.
    func update(using context: RenderContext) {
        // Create an entirely new set of layers in memory based on the current context.
        let allNewLayers = createSheetLayers(context: context)
        
        // Atomically replace the old sublayers with the new ones.
        // Core Animation is highly optimized for this operation.
        rootLayer.sublayers = allNewLayers
    }

    /// The sheet is purely visual and does not participate in hit-testing.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }

    // MARK: - Private Helpers
    
    /// This private helper contains the logic from the old `makeLayers` method.
    /// It is now responsible for generating a fresh array of layers on demand.
    private func createSheetLayers(context: RenderContext) -> [CALayer] {
        var generatedLayers: [CALayer] = []

        // Spacing can be calculated from context or be constant.
        let hSpacing = 10 * unitsPerMM
        let vSpacing = 10 * unitsPerMM

        // Use the new, ordered tuple array for cellValues.
        let metrics = DrawingMetrics(
            viewBounds: context.hostViewBounds,
            inset: inset,
            horizontalTickSpacing: hSpacing,
            verticalTickSpacing: vSpacing,
            cellHeight: cellHeight,
            cellValues: context.sheetCellValues
        )
        
        // The order of appends determines the Z-order of the drawing.
        generatedLayers.append(contentsOf: createBackgroundLayers(metrics: metrics))
        generatedLayers.append(contentsOf: BorderDrawer().makeLayers(metrics: metrics, color: graphicColor.cgColor))

        if !context.sheetCellValues.isEmpty {
            let drawer = TitleBlockDrawer(
                cellValues: context.sheetCellValues,
                graphicColor: graphicColor,
                cellPad: cellPad,
                cellHeight: cellHeight,
                safeFont: safeFont
            )
            generatedLayers.append(contentsOf: drawer.makeLayers(metrics: metrics))
        }

        let rulerPositions: [RulerDrawer.Position] = [.top, .bottom, .left, .right]
        rulerPositions.forEach { position in
            let drawer = RulerDrawer(
                position: position,
                graphicColor: graphicColor,
                safeFont: safeFont,
                showLabels: true
            )
            generatedLayers.append(contentsOf: drawer.makeLayers(metrics: metrics))
        }
        
        return generatedLayers
    }
    
    private func createBackgroundLayers(metrics: DrawingMetrics) -> [CALayer] {
        let rulerBGPath = CGMutablePath()
        rulerBGPath.addRect(metrics.outerBounds)
        rulerBGPath.addRect(metrics.innerBounds)

        let rulerBGLayer = CAShapeLayer()
        rulerBGLayer.path = rulerBGPath
        rulerBGLayer.fillRule = .evenOdd
        rulerBGLayer.fillColor = NSColor.white.cgColor
        
        var backgroundLayers: [CALayer] = [rulerBGLayer]
        
        // Use the `isEmpty` check on the cellValues count, not the frame.
        if metrics.titleBlockFrame.height > 0 {
            let titleBGLayer = CAShapeLayer()
            titleBGLayer.path = CGPath(rect: metrics.titleBlockFrame, transform: nil)
            titleBGLayer.fillColor = NSColor.white.cgColor
            backgroundLayers.append(titleBGLayer)
        }
        return backgroundLayers
    }
    
    private func safeFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
}
