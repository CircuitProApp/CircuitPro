import AppKit

/// Renders the marquee selection rectangle on the canvas.
///
/// This layer reads the `marqueeRect` from the render context and draws a dashed
/// rectangle. The `MarqueeInteraction` is responsible for updating this rectangle
/// during a drag.
class MarqueeRenderLayer: RenderLayer {
    
    private let shapeLayer = CAShapeLayer()

    func install(on hostLayer: CALayer) {
        // Configure the visual appearance of the marquee rectangle.
        shapeLayer.fillColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        shapeLayer.lineCap = .butt
        shapeLayer.lineJoin = .miter
        
        hostLayer.addSublayer(shapeLayer)
    }

    func update(using context: RenderContext) {
        // The `CanvasView` is responsible for creating the context and passing
        // the marqueeRect from the `CanvasManager` into it.
        if let rect = context.environment.marqueeRect {
            shapeLayer.isHidden = false

            // Adjust line width and dash pattern for the current canvas magnification.
            let scale = 1.0 / max(context.magnification, .ulpOfOne)
            let path = CGPath(rect: rect, transform: nil)
            let dashPattern: [NSNumber] = [4, 2]

            shapeLayer.path = path
            shapeLayer.lineWidth = 1.0 * scale
            shapeLayer.lineDashPattern = dashPattern.map { NSNumber(value: $0.doubleValue * scale) }
        } else {
            // If there's no marquee, hide the layer.
            shapeLayer.isHidden = true
            shapeLayer.path = nil
        }
    }
}
