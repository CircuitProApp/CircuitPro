//
//  GuideRenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


import AppKit

class GuideRenderLayer: RenderLayer {
    var layerKey: String = "guides"

    func makeLayers(context: RenderContext) -> [CALayer] {
        guard context.showGuides else { return [] }

        let origin = CGPoint(x: context.hostViewBounds.midX, y: context.hostViewBounds.midY)
        let lineWidth = 1.0 / max(context.magnification, .ulpOfOne)

        // X-axis Layer
        let xPath = CGMutablePath()
        xPath.move(to: CGPoint(x: context.hostViewBounds.minX, y: origin.y))
        xPath.addLine(to: CGPoint(x: context.hostViewBounds.maxX, y: origin.y))
        
        let xAxisLayer = CAShapeLayer()
        xAxisLayer.path = xPath
        xAxisLayer.strokeColor = NSColor.systemRed.cgColor
        xAxisLayer.lineWidth = lineWidth
        
        // Y-axis Layer
        let yPath = CGMutablePath()
        yPath.move(to: CGPoint(x: origin.x, y: context.hostViewBounds.minY))
        yPath.addLine(to: CGPoint(x: origin.x, y: context.hostViewBounds.maxY))

        let yAxisLayer = CAShapeLayer()
        yAxisLayer.path = yPath
        yAxisLayer.strokeColor = NSColor.systemGreen.cgColor
        yAxisLayer.lineWidth = lineWidth
        
        return [xAxisLayer, yAxisLayer]
    }
}