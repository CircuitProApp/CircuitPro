import AppKit

class GridRenderLayer: RenderLayer {

    private let majorGridLayer = CAShapeLayer()
    private let minorGridLayer = CAShapeLayer()

    // Fade as you zoom out: 1 at/above start, 0 at/below end
    private let fadeOutStart: CGFloat = 0.60
    private let fadeOutEnd: CGFloat   = 0.45

    private let majorBaseAlpha: CGFloat = 0.8
    private let minorBaseAlpha: CGFloat = 0.4

    func install(on hostLayer: CALayer) {
        majorGridLayer.fillColor = NSColor.gray.withAlphaComponent(majorBaseAlpha).cgColor
        minorGridLayer.fillColor = NSColor.gray.withAlphaComponent(minorBaseAlpha).cgColor
        majorGridLayer.strokeColor = nil
        minorGridLayer.strokeColor = nil
        majorGridLayer.zPosition = -100
        minorGridLayer.zPosition = -100

        hostLayer.addSublayer(majorGridLayer)
        hostLayer.addSublayer(minorGridLayer)
    }

    func update(using context: RenderContext) {
        // One transaction that disables all implicit animations for this update.
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let hostBounds = context.hostViewBounds
        let visible = context.visibleRect

        // Align frames to host bounds for local coordinates and natural clipping.
        majorGridLayer.frame = hostBounds
        minorGridLayer.frame = hostBounds

        // Compute fade factor based on magnification.
        let f = fadeFactor(magnification: context.magnification)

        if hostBounds.isEmpty || visible.isEmpty || f <= 0 {
            // Fully faded or nothing to show: hide and free geometry.
            majorGridLayer.isHidden = true
            minorGridLayer.isHidden = true
            majorGridLayer.path = nil
            minorGridLayer.path = nil
            CATransaction.commit()
            return
        }

        // Ensure layers are visible while faded-in.
        if majorGridLayer.isHidden {
            majorGridLayer.isHidden = false
            minorGridLayer.isHidden = false
        }

        // Apply fade via fillColor alpha.
        let majorAlpha = clamp01(majorBaseAlpha * f)
        let minorAlpha = clamp01(minorBaseAlpha * f)
        majorGridLayer.fillColor = NSColor.gray.withAlphaComponent(majorAlpha).cgColor
        minorGridLayer.fillColor = NSColor.gray.withAlphaComponent(minorAlpha).cgColor

        // Build geometry only when visible.
        let unitSpacing = context.environment.configuration.grid.spacing.canvasPoints
        let spacing = adjustedSpacing(unitSpacing: unitSpacing, magnification: context.magnification)
        if spacing <= 0 {
            majorGridLayer.path = nil
            minorGridLayer.path = nil
            CATransaction.commit()
            return
        }

        let dotRadius = 1.0 / max(context.magnification, 1.0)

        // Clamp drawing to host bounds and what’s visible to avoid extra work.
        var clipRect = visible.intersection(hostBounds)
        if clipRect.isNull || clipRect.isEmpty {
            majorGridLayer.path = nil
            minorGridLayer.path = nil
            CATransaction.commit()
            return
        }
        clipRect = clipRect.insetBy(dx: dotRadius, dy: dotRadius)
        if clipRect.isNull || clipRect.isEmpty {
            majorGridLayer.path = nil
            minorGridLayer.path = nil
            CATransaction.commit()
            return
        }

        let majorPath = CGMutablePath()
        let minorPath = CGMutablePath()

        let gridOrigin = CGPoint.zero

        let startX = previousMultiple(of: spacing, beforeOrEqualTo: clipRect.minX, offset: gridOrigin.x)
        let endX = clipRect.maxX
        let startY = previousMultiple(of: spacing, beforeOrEqualTo: clipRect.minY, offset: gridOrigin.y)
        let endY = clipRect.maxY

        let ox = hostBounds.origin.x
        let oy = hostBounds.origin.y

        var y = startY
        while y <= endY {
            let isYMajor = Int(round((y - gridOrigin.y) / spacing)) % 10 == 0
            var x = startX
            while x <= endX {
                let isXMajor = Int(round((x - gridOrigin.x) / spacing)) % 10 == 0
                let isMajor = isYMajor || isXMajor

                let rx = x - ox
                let ry = y - oy
                let dotRect = CGRect(x: rx - dotRadius, y: ry - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                if isMajor { majorPath.addEllipse(in: dotRect) } else { minorPath.addEllipse(in: dotRect) }

                x += spacing
            }
            y += spacing
        }

        majorGridLayer.path = majorPath
        minorGridLayer.path = minorPath

        CATransaction.commit()
    }

    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }

    private func fadeFactor(magnification m: CGFloat) -> CGFloat {
        if m <= fadeOutEnd { return 0 }
        if m >= fadeOutStart { return 1 }
        let t = (m - fadeOutEnd) / (fadeOutStart - fadeOutEnd)
        // For a softer curve, you can use: return t * t * (3 - 2 * t)
        return t
    }

    private func clamp01(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }

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
