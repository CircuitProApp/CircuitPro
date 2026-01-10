import AppKit

/// A render layer that draws X and Y axes in the center of the current viewport.
/// These axes move as the user pans, always marking the screen's center point.
class AxesRenderLayer: RenderLayer {

    // Separate shape layers for X and Y
    private let xAxisLayer = CAShapeLayer()
    private let yAxisLayer = CAShapeLayer()

    /// Sets up the visual properties of the axes layers and adds them to the host layer.
    func install(on hostLayer: CALayer) {
        // X axis style (red, dashed)
        xAxisLayer.fillColor = nil
        xAxisLayer.strokeColor = NSColor.systemRed.cgColor
        xAxisLayer.zPosition = -50

        yAxisLayer.fillColor = nil
        yAxisLayer.strokeColor = NSColor.systemGreen.cgColor
        yAxisLayer.zPosition = -50

        hostLayer.addSublayer(xAxisLayer)
        hostLayer.addSublayer(yAxisLayer)
    }

    /// Redraws the axes in the center of the current visible rectangle on each frame.
    func update(using context: RenderContext) {
        let bounds = context.canvasBounds
        let scale = 1.0 / max(context.magnification, .ulpOfOne)
        let centerModelPoint = CGPoint(x: bounds.midX, y: bounds.midY)

        // Path for X axis
        let xPath = CGMutablePath()
        xPath.move(to: CGPoint(x: bounds.minX, y: centerModelPoint.y))
        xPath.addLine(to: CGPoint(x: bounds.maxX, y: centerModelPoint.y))
        xAxisLayer.path = xPath
        xAxisLayer.lineWidth = 1.0 * scale

        // Path for Y axis
        let yPath = CGMutablePath()
        yPath.move(to: CGPoint(x: centerModelPoint.x, y: bounds.minY))
        yPath.addLine(to: CGPoint(x: centerModelPoint.x, y: bounds.maxY))
        yAxisLayer.path = yPath
        yAxisLayer.lineWidth = 1.0 * scale
    }
}
