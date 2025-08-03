import AppKit

class CrosshairsRenderLayer: RenderLayer {
    var layerKey: String = "crosshairs"

    // 1. The layer is now a persistent property of the renderer.
    private let shapeLayer = CAShapeLayer()

    /// **NEW:** Called once to create the layer and add it to the host view's layer tree.
    func install(on hostLayer: CALayer) {
        // Set up constant properties that never change.
        shapeLayer.fillColor = nil // A crosshair is never filled.
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        shapeLayer.lineCap = .round

        // Add the persistent layer to the host.
        hostLayer.addSublayer(shapeLayer)
    }

    /// **NEW:** Updates the properties of the existing layer on every redraw.
    func update(using context: RenderContext) {
        // If the style is hidden or there's no mouse location, hide the layer.
        guard context.crosshairsStyle != .hidden, let point = context.mouseLocation else {
            shapeLayer.isHidden = true
            shapeLayer.path = nil
            return
        }

        // Make sure the layer is visible.
        shapeLayer.isHidden = false

        // Calculate dynamic properties from the context.
        let path = CGMutablePath()
        let bounds = context.hostViewBounds
        let scale = 1.0 / max(context.magnification, .ulpOfOne)

        // Build the path based on the current style.
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
            // This case is handled by the guard statement above.
            break
        }

        // Update the dynamic properties of the existing layer.
        shapeLayer.path = path
        shapeLayer.lineWidth = 1.0 * scale
    }
    
    /// The crosshairs are purely visual and should not be interactive.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }
}
