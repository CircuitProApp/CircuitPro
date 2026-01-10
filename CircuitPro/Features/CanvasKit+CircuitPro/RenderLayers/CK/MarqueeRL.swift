import AppKit

struct MarqueeRL: CKRenderLayer {
    @CKContext var context

    var marqueeColor: CGColor {
        context.environment.canvasTheme.crosshairColor
    }

    var strokeWidth: CGFloat {
        1.0 / max(context.magnification, .ulpOfOne)
    }

    var body: CKLayer {
        if let rect = context.environment.marqueeRect {
            marqueeRect(rect)
        } else {
            CKLayer.empty
        }
    }

    private func marqueeRect(_ rect: CGRect) -> CKRectangle {
        let dashPattern: [CGFloat] = [4 * strokeWidth, 2 * strokeWidth]

        return CKRectangle()
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .fill(marqueeColor.copy(alpha: 0.1) ?? .clear)
            .stroke(marqueeColor, width: strokeWidth)
            .lineCap(.butt)
            .lineJoin(.miter)
            .lineDash(dashPattern)
    }
}
