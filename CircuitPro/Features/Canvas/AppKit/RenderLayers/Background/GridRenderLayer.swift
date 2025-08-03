import AppKit

class GridRenderLayer: RenderLayer {
    var layerKey: String = "grid"

    func makeLayers(context: RenderContext) -> [CALayer] {
        guard context.magnification >= 0.35 else { return [] }

        let majorLayer = CAShapeLayer()
        let minorLayer = CAShapeLayer()
        majorLayer.fillColor = NSColor.gray.withAlphaComponent(1.0).cgColor
        minorLayer.fillColor = NSColor.gray.withAlphaComponent(0.5).cgColor
        
        // Use the full host view bounds as the drawing area.
        let drawingRect = context.hostViewBounds
        let spacing = adjustedSpacing(for: context.snapGridSize, magnification: context.magnification)
        let dotRadius = (1.0 / max(context.magnification, 1.0))
        
        let majorPath = CGMutablePath()
        let minorPath = CGMutablePath()

        let gridOrigin = context.showGuides ? CGPoint(x: drawingRect.midX, y: drawingRect.midY) : .zero
        
        let startX = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minX, offset: gridOrigin.x)
        let endX = drawingRect.maxX
        
        var currentY = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minY, offset: gridOrigin.y)

        let endY = drawingRect.maxY
        
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
        
        majorLayer.path = majorPath
        minorLayer.path = minorPath
        
        return [majorLayer, minorLayer]
    }
    
    // MARK: - Helpers from DottedBackgroundView
    
    private func previousMultiple(of step: CGFloat, beforeOrEqualTo value: CGFloat, offset: CGFloat) -> CGFloat {
        guard step > 0 else { return value }
        return floor((value - offset) / step) * step + offset
    }

    private func adjustedSpacing(for unitSpacing: CGFloat, magnification: CGFloat) -> CGFloat {
        // This logic can be simplified or adjusted as needed.
        // For now, let's just use the direct grid size.
        return unitSpacing
    }
}
