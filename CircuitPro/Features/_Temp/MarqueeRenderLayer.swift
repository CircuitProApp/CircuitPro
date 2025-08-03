//
//  MarqueeRenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


import AppKit

class MarqueeRenderLayer: RenderLayer {
    var layerKey: String = "marquee"

    func makeLayers(context: RenderContext) -> [CALayer] {
        guard let rect = context.marqueeRect else { return [] }

        let path = CGPath(rect: rect, transform: nil)
        let scale = 1.0 / max(context.magnification, .ulpOfOne)

        let params = DrawingParameters(
            path: path,
            lineWidth: 1.0 * scale,
            fillColor: NSColor.systemBlue.withAlphaComponent(0.1).cgColor,
            strokeColor: NSColor.systemBlue.cgColor,
            lineDashPattern: ([4, 2] as [NSNumber]).map { NSNumber(value: $0.doubleValue * scale) },
            lineCap: .butt,
            lineJoin: .miter
        )
        
        return [createLayer(from: params)]
    }
    
    private func createLayer(from parameters: DrawingParameters) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth
        layer.lineDashPattern = parameters.lineDashPattern
        layer.lineCap = parameters.lineCap
        layer.lineJoin = parameters.lineJoin
        return layer
    }
}