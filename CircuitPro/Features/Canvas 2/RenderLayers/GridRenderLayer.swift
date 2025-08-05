import AppKit

class GridRenderLayer: RenderLayer {
    var layerKey: String = "grid"

    private let majorGridLayer = CAShapeLayer()
    private let minorGridLayer = CAShapeLayer()

    func install(on hostLayer: CALayer) {
        majorGridLayer.fillColor = NSColor.gray.withAlphaComponent(0.8).cgColor
        minorGridLayer.fillColor = NSColor.gray.withAlphaComponent(0.4).cgColor
        majorGridLayer.strokeColor = nil
        minorGridLayer.strokeColor = nil

        hostLayer.addSublayer(majorGridLayer)
        hostLayer.addSublayer(minorGridLayer)
    }

    func update(using context: RenderContext) {
        guard context.magnification >= 0.35 else {
            majorGridLayer.isHidden = true
            minorGridLayer.isHidden = true
            return
        }

        majorGridLayer.isHidden = false
        minorGridLayer.isHidden = false

        let drawingRect = context.hostViewBounds
       
        // --- THIS IS THE FIX ---
        // 1. Explicitly define the type for safety.
        // 2. The grid origin should be fixed at (0,0) in world coordinates
        //    so it doesn't move when the user pans the canvas.
        let spacing: CGFloat = context.environment.grid.spacing
        let gridOrigin = CGPoint.zero
        
        let dotRadius = 1.0 / context.magnification

        let majorPath = CGMutablePath()
        let minorPath = CGMutablePath()
        
        let startX = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minX, offset: gridOrigin.x)
        let endX = drawingRect.maxX
        let startY = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minY, offset: gridOrigin.y)
        let endY = drawingRect.maxY
        
        var currentY = startY
        while currentY <= endY {
            // Use a simple integer division check for major lines.
            // Using fmod() with floating point numbers can lead to precision errors.
            let isYMajor = Int(round((currentY - gridOrigin.y) / spacing)) % 10 == 0

            var currentX = startX
            while currentX <= endX {
                let isXMajor = Int(round((currentX - gridOrigin.x) / spacing)) % 10 == 0
                let isMajor = isYMajor || isXMajor
                
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
        
        majorGridLayer.path = majorPath
        minorGridLayer.path = minorPath
    }
    
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }

    private func previousMultiple(of step: CGFloat, beforeOrEqualTo value: CGFloat, offset: CGFloat) -> CGFloat {
        guard step > 0 else { return value }
        return floor((value - offset) / step) * step + offset
    }
}
