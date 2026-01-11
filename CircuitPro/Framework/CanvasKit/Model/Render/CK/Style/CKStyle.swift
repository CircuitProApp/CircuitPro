import AppKit

struct CKStyle {
    var position: CGPoint?
    var size: CGSize?
    var fillColor: CGColor?
    var fillRule: CAShapeLayerFillRule = .nonZero
    var strokeColor: CGColor?
    var strokeWidth: CGFloat = 1.0
    var lineCap: CAShapeLayerLineCap = .round
    var lineJoin: CAShapeLayerLineJoin = .round
    var miterLimit: CGFloat = 10
    var lineDash: [NSNumber]?
    var clipPath: CGPath?
    var halos: [CKHalo] = []
    var rotation: CGFloat = 0
}

struct CKHalo {
    var color: CGColor
    var width: CGFloat
}

extension CKStyled {
    func frame(width: CGFloat, height: CGFloat) -> CKStyled<Base> {
        var copy = self
        copy.style.size = CGSize(width: width, height: height)
        return copy
    }

    func position(_ point: CGPoint) -> CKStyled<Base> {
        var copy = self
        copy.style.position = point
        return copy
    }

    func position(x: CGFloat, y: CGFloat) -> CKStyled<Base> {
        position(CGPoint(x: x, y: y))
    }

    func fill(_ color: CGColor) -> CKStyled<Base> {
        var copy = self
        copy.style.fillColor = color
        return copy
    }

    func fill(_ color: CGColor, rule: CAShapeLayerFillRule) -> CKStyled<Base> {
        var copy = self
        copy.style.fillColor = color
        copy.style.fillRule = rule
        return copy
    }

    func stroke(_ color: CGColor, width: CGFloat = 1.0) -> CKStyled<Base> {
        var copy = self
        copy.style.strokeColor = color
        copy.style.strokeWidth = width
        return copy
    }

    func lineCap(_ lineCap: CAShapeLayerLineCap) -> CKStyled<Base> {
        var copy = self
        copy.style.lineCap = lineCap
        return copy
    }

    func lineJoin(_ lineJoin: CAShapeLayerLineJoin) -> CKStyled<Base> {
        var copy = self
        copy.style.lineJoin = lineJoin
        return copy
    }

    func miterLimit(_ limit: CGFloat) -> CKStyled<Base> {
        var copy = self
        copy.style.miterLimit = limit
        return copy
    }

    func lineDash(_ pattern: [CGFloat]) -> CKStyled<Base> {
        var copy = self
        copy.style.lineDash = pattern.map { NSNumber(value: Double($0)) }
        return copy
    }

    func halo(_ color: CGColor, width: CGFloat) -> CKStyled<Base> {
        var copy = self
        copy.style.halos.append(CKHalo(color: color, width: width))
        return copy
    }

    func clip(to rect: CGRect) -> CKStyled<Base> {
        var copy = self
        copy.style.clipPath = CGPath(rect: rect, transform: nil)
        return copy
    }

    func clip(_ path: CGPath) -> CKStyled<Base> {
        var copy = self
        copy.style.clipPath = path
        return copy
    }

    func rotation(_ angle: CGFloat) -> CKStyled<Base> {
        var copy = self
        copy.style.rotation = angle
        return copy
    }
}

extension CKPathView {
    func styled() -> CKStyled<Self> {
        CKStyled(base: self, style: defaultStyle)
    }

    func frame(width: CGFloat, height: CGFloat) -> CKStyled<Self> {
        styled().frame(width: width, height: height)
    }

    func position(_ point: CGPoint) -> CKStyled<Self> {
        styled().position(point)
    }

    func position(x: CGFloat, y: CGFloat) -> CKStyled<Self> {
        styled().position(x: x, y: y)
    }

    func fill(_ color: CGColor) -> CKStyled<Self> {
        styled().fill(color)
    }

    func fill(_ color: CGColor, rule: CAShapeLayerFillRule) -> CKStyled<Self> {
        styled().fill(color, rule: rule)
    }

    func stroke(_ color: CGColor, width: CGFloat = 1.0) -> CKStyled<Self> {
        styled().stroke(color, width: width)
    }

    func lineCap(_ lineCap: CAShapeLayerLineCap) -> CKStyled<Self> {
        styled().lineCap(lineCap)
    }

    func lineJoin(_ lineJoin: CAShapeLayerLineJoin) -> CKStyled<Self> {
        styled().lineJoin(lineJoin)
    }

    func miterLimit(_ limit: CGFloat) -> CKStyled<Self> {
        styled().miterLimit(limit)
    }

    func lineDash(_ pattern: [CGFloat]) -> CKStyled<Self> {
        styled().lineDash(pattern)
    }

    func halo(_ color: CGColor, width: CGFloat) -> CKStyled<Self> {
        styled().halo(color, width: width)
    }

    func clip(to rect: CGRect) -> CKStyled<Self> {
        styled().clip(to: rect)
    }

    func clip(_ path: CGPath) -> CKStyled<Self> {
        styled().clip(path)
    }

    func rotation(_ angle: CGFloat) -> CKStyled<Self> {
        styled().rotation(angle)
    }
}

func ckPrimitives(for path: CGPath, style: CKStyle) -> [DrawingPrimitive] {
    guard !path.isEmpty else { return [] }
    var primitives: [DrawingPrimitive] = []
    if !style.halos.isEmpty {
        for halo in style.halos where halo.width > 0 {
            primitives.append(
                .stroke(
                    path: path,
                    color: halo.color,
                    lineWidth: halo.width,
                    lineCap: style.lineCap,
                    lineJoin: style.lineJoin,
                    miterLimit: style.miterLimit,
                    lineDash: style.lineDash,
                    clipPath: style.clipPath
                )
            )
        }
    }
    if let fillColor = style.fillColor {
        primitives.append(
            .fill(
                path: path,
                color: fillColor,
                rule: style.fillRule,
                clipPath: style.clipPath
            )
        )
    }
    if let strokeColor = style.strokeColor {
        primitives.append(
            .stroke(
                path: path,
                color: strokeColor,
                lineWidth: style.strokeWidth,
                lineCap: style.lineCap,
                lineJoin: style.lineJoin,
                miterLimit: style.miterLimit,
                lineDash: style.lineDash,
                clipPath: style.clipPath
            )
        )
    }
    return primitives
}
