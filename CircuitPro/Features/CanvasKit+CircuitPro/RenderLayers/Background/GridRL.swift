import AppKit

struct GridRL: CKRenderLayer {
    @CKContext var context

    private let fadeOutStart: CGFloat = 0.60
    private let fadeOutEnd: CGFloat = 0.45
    private let majorBaseAlpha: CGFloat = 0.8
    private let minorBaseAlpha: CGFloat = 0.4

    var body: CKLayer {
        if !context.environment.grid.isVisible {
            CKLayer.empty
        } else {
            gridLayer
        }
    }

    private var gridLayer: CKLayer {
        let hostBounds = context.canvasBounds
        let visible = context.visibleRect
        let fade = fadeFactor(magnification: context.magnification)
        if hostBounds.isEmpty || visible.isEmpty || fade <= 0 {
            return .empty
        }

        let unitSpacing = context.environment.grid.spacing.canvasPoints
        let spacing = adjustedSpacing(unitSpacing: unitSpacing, magnification: context.magnification)
        if spacing <= 0 {
            return .empty
        }

        let dotRadius = 1.0 / max(context.magnification, 1.0)
        var clipRect = visible.intersection(hostBounds)
        if clipRect.isNull || clipRect.isEmpty {
            return .empty
        }
        clipRect = clipRect.insetBy(dx: dotRadius, dy: dotRadius)
        if clipRect.isNull || clipRect.isEmpty {
            return .empty
        }

        let (majorPath, minorPath) = dotGridPaths(
            clipRect: clipRect,
            spacing: spacing,
            dotRadius: dotRadius,
            hostBounds: hostBounds
        )

        let baseColor = context.environment.canvasTheme.gridPrimaryColor
        let majorColor = applyAlpha(majorBaseAlpha, to: baseColor)
        let minorColor = applyAlpha(minorBaseAlpha, to: baseColor)

        return CKLayer {
            majorPath.fill(majorColor)
            minorPath.fill(minorColor)
        }
        .opacity(fade)
    }

    private func applyAlpha(_ alpha: CGFloat, to color: CGColor) -> CGColor {
        let base = NSColor(cgColor: color) ?? NSColor.gray
        return base.withAlphaComponent((base.alphaComponent * alpha).clamped(to: 0...1)).cgColor
    }

    private func previousMultiple(of step: CGFloat, beforeOrEqualTo value: CGFloat, offset: CGFloat) -> CGFloat {
        guard step > 0 else { return value }
        return floor((value - offset) / step) * step + offset
    }

    private func dotGridPaths(
        clipRect: CGRect,
        spacing: CGFloat,
        dotRadius: CGFloat,
        hostBounds: CGRect
    ) -> (major: CKPath, minor: CKPath) {
        let gridOrigin = CGPoint.zero
        let startX = previousMultiple(of: spacing, beforeOrEqualTo: clipRect.minX, offset: gridOrigin.x)
        let endX = clipRect.maxX
        let startY = previousMultiple(of: spacing, beforeOrEqualTo: clipRect.minY, offset: gridOrigin.y)
        let endY = clipRect.maxY

        let ox = hostBounds.origin.x
        let oy = hostBounds.origin.y
        let localClip = clipRect.offsetBy(dx: -hostBounds.origin.x, dy: -hostBounds.origin.y)

        let majorPath = CGMutablePath()
        let minorPath = CGMutablePath()

        for y in stride(from: startY, through: endY, by: spacing) {
            let isYMajor = Int(round((y - gridOrigin.y) / spacing)) % 10 == 0
            for x in stride(from: startX, through: endX, by: spacing) {
                let isXMajor = Int(round((x - gridOrigin.x) / spacing)) % 10 == 0
                let isMajor = isYMajor || isXMajor

                let rx = x - ox
                let ry = y - oy
                let dotRect = CGRect(
                    x: rx - dotRadius,
                    y: ry - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                if isMajor {
                    majorPath.addEllipse(in: dotRect)
                } else {
                    minorPath.addEllipse(in: dotRect)
                }
            }
        }

        let major = CKPath(path: majorPath).clip(to: localClip)
        let minor = CKPath(path: minorPath).clip(to: localClip)

        return (major, minor)
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

    private func fadeFactor(magnification m: CGFloat) -> CGFloat {
        if m <= fadeOutEnd { return 0 }
        if m >= fadeOutStart { return 1 }
        return (m - fadeOutEnd) / (fadeOutStart - fadeOutEnd)
    }
}
