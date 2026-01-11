import AppKit

struct CKRectangle: CKPathView {
    var cornerRadius: CGFloat = 0

    init(cornerRadius: CGFloat = 0) {
        self.cornerRadius = cornerRadius
    }

    func path(in context: RenderContext, style: CKStyle) -> CGPath {
        let size = style.size ?? .zero
        let center = style.position ?? .zero
        let origin = CGPoint(
            x: center.x - size.width * 0.5,
            y: center.y - size.height * 0.5
        )
        let rect = CGRect(origin: origin, size: size)
        return CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }
}
