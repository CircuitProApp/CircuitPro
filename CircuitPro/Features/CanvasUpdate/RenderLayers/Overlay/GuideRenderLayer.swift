import AppKit

class GuideRenderLayer: RenderLayer {
    var layerKey: String = "guides"

    // 1. The layers are now persistent properties of the renderer.
    private let xAxisLayer = CAShapeLayer()
    private let yAxisLayer = CAShapeLayer()

    /// **NEW:** Creates the layers and adds them to the host view's layer tree once.
    func install(on hostLayer: CALayer) {
        // Set up constant properties that never change.
        xAxisLayer.strokeColor = NSColor.systemRed.cgColor
        xAxisLayer.fillColor = nil
        
        yAxisLayer.strokeColor = NSColor.systemGreen.cgColor
        yAxisLayer.fillColor = nil

        // Add the persistent layers to the host.
        hostLayer.addSublayer(xAxisLayer)
        hostLayer.addSublayer(yAxisLayer)
    }

    /// **NEW:** Updates the properties of the existing layers on every redraw.
    func update(using context: RenderContext) {
        // If guides are turned off, simply hide the layers. This is very cheap.
//        guard context.showGuides else {
//            xAxisLayer.isHidden = true
//            yAxisLayer.isHidden = true
//            return
//        }

        // If guides are shown, make sure the layers are visible.
        xAxisLayer.isHidden = false
        yAxisLayer.isHidden = false
        
        // Calculate the dynamic properties from the context.
        let origin = CGPoint(x: context.hostViewBounds.midX, y: context.hostViewBounds.midY)
        let lineWidth = 1.0 / max(context.magnification, .ulpOfOne)

        // Update the dynamic properties of the existing layers.
        xAxisLayer.lineWidth = lineWidth
        yAxisLayer.lineWidth = lineWidth

        // X-axis Path
        let xPath = CGMutablePath()
        xPath.move(to: CGPoint(x: context.hostViewBounds.minX, y: origin.y))
        xPath.addLine(to: CGPoint(x: context.hostViewBounds.maxX, y: origin.y))
        xAxisLayer.path = xPath

        // Y-axis Path
        let yPath = CGMutablePath()
        yPath.move(to: CGPoint(x: origin.x, y: context.hostViewBounds.minY))
        yPath.addLine(to: CGPoint(x: origin.x, y: context.hostViewBounds.maxY))
        yAxisLayer.path = yPath
    }
    
    /// Guides are not interactive, so this layer does not participate in hit-testing.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }
}
