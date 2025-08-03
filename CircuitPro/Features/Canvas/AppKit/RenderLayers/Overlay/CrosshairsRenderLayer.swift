//
//  CrosshairsRenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


import AppKit

class CrosshairsRenderLayer: RenderLayer {
    var layerKey: String = "crosshairs"

    func makeLayers(context: RenderContext) -> [CALayer] {
        guard context.crosshairsStyle != .hidden, let point = context.mouseLocation else {
            return []
        }

        let path = CGMutablePath()
        let bounds = context.hostViewBounds
        
        switch context.crosshairsStyle {
        case .fullScreenLines:
            path.move(to: CGPoint(x: point.x, y: bounds.minY))
            path.addLine(to: CGPoint(x: point.x, y: bounds.maxY))
            path.move(to: CGPoint(x: bounds.minX, y: point.y))
            path.addLine(to: CGPoint(x: bounds.maxX, y: point.y))

        case .centeredCross:
            let size: CGFloat = 20.0
            let half = size / 2.0
            path.move(to: CGPoint(x: point.x - half, y: point.y))
            path.addLine(to: CGPoint(x: point.x + half, y: point.y))
            path.move(to: CGPoint(x: point.x, y: point.y - half))
            path.addLine(to: CGPoint(x: point.x, y: point.y + half))

        case .hidden:
            break
        }
        
        let scale = 1.0 / max(context.magnification, .ulpOfOne)
        let params = DrawingParameters(
            path: path,
            lineWidth: 1.0 * scale,
            fillColor: nil,
            strokeColor: NSColor.systemBlue.cgColor,
            lineCap: .round
        )

        return [createLayer(from: params)]
    }

    private func createLayer(from parameters: DrawingParameters) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth
        layer.lineCap = parameters.lineCap
        return layer
    }
}