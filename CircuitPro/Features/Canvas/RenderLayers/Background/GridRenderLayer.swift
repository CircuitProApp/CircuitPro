import AppKit

class GridRenderLayer: RenderLayer {

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

        let drawingRect = context.visibleRect
        

        guard !drawingRect.isEmpty else {
            majorGridLayer.path = nil
            minorGridLayer.path = nil
            return
        }

        let unitSpacing = context.environment.configuration.grid.spacing.canvasPoints
        let spacing = adjustedSpacing(unitSpacing: unitSpacing, magnification: context.magnification)
        
        let gridOrigin = CGPoint.zero
        
        guard spacing > 0 else {
            majorGridLayer.isHidden = true
            minorGridLayer.isHidden = true
            return
        }
        
        let dotRadius = 1.0 / max(context.magnification, 1.0)

        let majorPath = CGMutablePath()
        let minorPath = CGMutablePath()
        
        // These calculations now correctly use the smaller `drawingRect`.
        let startX = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minX, offset: gridOrigin.x)
        let endX = drawingRect.maxX
        let startY = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minY, offset: gridOrigin.y)
        let endY = drawingRect.maxY
        
        var currentY = startY
        while currentY <= endY {
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
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        majorGridLayer.path = majorPath
        minorGridLayer.path = minorPath
        CATransaction.commit()
    }
    
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }

    private func previousMultiple(of step: CGFloat, beforeOrEqualTo value: CGFloat, offset: CGFloat) -> CGFloat {
        guard step > 0 else { return value }
        return floor((value - offset) / step) * step + offset
    }

    private func adjustedSpacing(unitSpacing: CGFloat, magnification: CGFloat) -> CGFloat {
        switch unitSpacing {
        case 5:
            return magnification < 2.0 ? 10 : 5
        case 2.5:
            if magnification < 2.0 { return 10 }
            else if magnification < 3.0 { return 5 }
            else { return 2.5 }
        case 1:
            if magnification < 2.5 { return 8 }
            else if magnification < 5.0 { return 4 }
            else if magnification < 10 { return 2 }
            else { return 1 }
        default:
            return unitSpacing
        }
    }
}
