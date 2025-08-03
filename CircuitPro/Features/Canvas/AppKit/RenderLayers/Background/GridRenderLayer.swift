import AppKit

class GridRenderLayer: RenderLayer {
    var layerKey: String = "grid"

    // 1. The layers are now persistent properties of the renderer.
    private let majorGridLayer = CAShapeLayer()
    private let minorGridLayer = CAShapeLayer()

    /// **NEW:** Called once to create and configure the layers.
    func install(on hostLayer: CALayer) {
        // Set constant properties that never change.
        majorGridLayer.fillColor = NSColor.gray.withAlphaComponent(0.8).cgColor
        minorGridLayer.fillColor = NSColor.gray.withAlphaComponent(0.4).cgColor

        // Add the persistent layers to the host.
        hostLayer.addSublayer(majorGridLayer)
        hostLayer.addSublayer(minorGridLayer)
    }

    /// **NEW:** Updates the paths of the existing grid layers on every redraw.
    func update(using context: RenderContext) {
        // Hide the grid entirely if zoomed out too far. This is cheap.
        guard context.magnification >= 0.35 else {
            majorGridLayer.isHidden = true
            minorGridLayer.isHidden = true
            return
        }

        // Ensure layers are visible if we are drawing.
        majorGridLayer.isHidden = false
        minorGridLayer.isHidden = false

        // Calculate dynamic properties from the context.
        let drawingRect = context.hostViewBounds
        let spacing = context.snapGridSize // Use the snap grid size directly for now.
        let dotRadius = 1.0 / max(context.magnification, 1.0)
        let gridOrigin = context.showGuides ? CGPoint(x: drawingRect.midX, y: drawingRect.midY) : .zero
        
        let majorPath = CGMutablePath()
        let minorPath = CGMutablePath()
        
        let startX = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minX, offset: gridOrigin.x)
        let endX = drawingRect.maxX
        let startY = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minY, offset: gridOrigin.y)
        let endY = drawingRect.maxY
        
        var currentY = startY
        while currentY <= endY {
            let yGridIndex = Int(round((currentY - gridOrigin.y) / spacing))
            let isYMajor = (yGridIndex % 10 == 0)

            var currentX = startX
            while currentX <= endX {
                let xGridIndex = Int(round((currentX - gridOrigin.x) / spacing))
                let isMajor = isYMajor || (xGridIndex % 10 == 0)
                
                let dotRect = CGRect(x: currentX - dotRadius, y: currentY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                if isMajor {
                    majorPath.addEllipse(in: dotRect)
                } else {
                    minorPath.addEllipse(in: dotRect)
                }
                currentX += spacing
            }
            currentY += spacing
        }
        
        // Update the paths of the existing layers.
        majorGridLayer.path = majorPath
        minorGridLayer.path = minorPath
    }
    
    /// The grid is purely visual and is not interactive.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }

    // MARK: - Private Helpers

    private func previousMultiple(of step: CGFloat, beforeOrEqualTo value: CGFloat, offset: CGFloat) -> CGFloat {
        guard step > 0 else { return value }
        return floor((value - offset) / step) * step + offset
    }
}
