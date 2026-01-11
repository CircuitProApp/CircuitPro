import AppKit

struct CKCircle: CKPathView {
    var radius: CGFloat

    init(radius: CGFloat) {
        self.radius = radius
    }

    func path(in context: RenderContext, style: CKStyle) -> CGPath {
        let center = style.position ?? .zero
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        return CGPath(ellipseIn: rect, transform: nil)
    }
}
