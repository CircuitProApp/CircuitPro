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
        
        // If the style is hidden or there's no mouse location, hide the layer.
        guard config.crosshairsStyle != .hidden, let mouseLocation = context.mouseLocation else {
            shapeLayer.isHidden = true
            shapeLayer.path = nil
            return
        }

        let snapService = SnapService(
            gridSize: config.grid.spacing.canvasPoints,
            isEnabled: config.snapping.isEnabled
        )
        
        let point = snapService.snap(mouseLocation)
        
        // Make sure the layer is visible.
        shapeLayer.isHidden = false

        // Calculate dynamic properties from the context.
        let path = CGMutablePath()
        let bounds = context.hostViewBounds
        let scale = 1.0 / max(context.magnification, .ulpOfOne)

        // Build the path based on the current style, using the (now snapped) point.
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
            // This case is handled by the guard statement above.
            break
        }

        // Update the dynamic properties of the existing layer.
        shapeLayer.path = path
        shapeLayer.lineWidth = 1.0 * scale
    }
    
    // The hitTest method remains the same, returning nil.
}
