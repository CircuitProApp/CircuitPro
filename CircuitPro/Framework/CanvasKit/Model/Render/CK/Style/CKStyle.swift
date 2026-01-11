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
}

extension CKPathView {
    func styled() -> CKStyled<Self> {
        CKStyled(base: self, style: defaultStyle)
    }

    func frame(width: CGFloat, height: CGFloat) -> CKStyled<Self> {
        styled().frame(width: width, height: height)
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
