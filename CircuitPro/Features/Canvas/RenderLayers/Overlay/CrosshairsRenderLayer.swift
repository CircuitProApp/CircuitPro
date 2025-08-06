import AppKit

class CrosshairsRenderLayer: RenderLayer {

    private let shapeLayer = CAShapeLayer()

    func install(on hostLayer: CALayer) {
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        shapeLayer.lineCap = .round
        hostLayer.addSublayer(shapeLayer)
    }

    func update(using context: RenderContext) {
        let config = context.environment.configuration
        
        // Use the new `processedMouseLocation` property from the context.
        // It will be nil if the raw location is nil, so this guard is sufficient.
        guard config.crosshairsStyle != .hidden, let point = context.processedMouseLocation else {
            shapeLayer.isHidden = true
            shapeLayer.path = nil
            return
        }
        
        // The manual snap service logic is now completely gone.

        shapeLayer.isHidden = false

        let path = CGMutablePath()
        let bounds = context.hostViewBounds
        let scale = 1.0 / max(context.magnification, .ulpOfOne)

        // The rest of your drawing logic uses the final `point` and remains unchanged.
        switch config.crosshairsStyle {
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

        shapeLayer.path = path
        shapeLayer.lineWidth = 1.0 * scale
    }
}
