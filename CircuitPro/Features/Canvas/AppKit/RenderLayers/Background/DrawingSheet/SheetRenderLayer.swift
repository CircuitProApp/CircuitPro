//
//  SheetRenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


import AppKit

class SheetRenderLayer: RenderLayer {
    var layerKey: String = "sheet"
    
    private let graphicColor: NSColor = .black
    private let inset: CGFloat = 20
    private let cellHeight: CGFloat = 25
    private let cellPad: CGFloat = 10
    private let unitsPerMM: CGFloat = 10
    
    func makeLayers(context: RenderContext) -> [CALayer] {
        var managedLayers: [CALayer] = []

        let hSpacing = 10 * unitsPerMM // 10mm
        let vSpacing = 10 * unitsPerMM

        let metrics = DrawingMetrics(
            viewBounds: context.hostViewBounds,
            inset: inset,
            horizontalTickSpacing: hSpacing,
            verticalTickSpacing: vSpacing,
            cellHeight: cellHeight,
            cellValues: context.sheetCellValues
        )
        
        managedLayers.append(contentsOf: createBackgroundLayers(metrics: metrics))
        managedLayers.append(contentsOf: BorderDrawer().makeLayers(metrics: metrics, color: graphicColor.cgColor))

        if !context.sheetCellValues.isEmpty {
            let drawer = TitleBlockDrawer(
                cellValues: context.sheetCellValues, graphicColor: graphicColor,
                cellPad: cellPad, cellHeight: cellHeight, safeFont: safeFont
            )
            managedLayers.append(contentsOf: drawer.makeLayers(metrics: metrics))
        }

        let rulerPositions: [RulerDrawer.Position] = [.top, .bottom, .left, .right]
        rulerPositions.forEach { position in
            let drawer = RulerDrawer(
                position: position, graphicColor: graphicColor,
                safeFont: safeFont, showLabels: true
            )
            managedLayers.append(contentsOf: drawer.makeLayers(metrics: metrics))
        }
        
        return managedLayers
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
        
        if !metrics.titleBlockFrame.isEmpty {
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