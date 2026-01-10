import AppKit

struct CKCircle: CKShape {
    var radius: CGFloat
    var style: CKStyle = .init()

    init(radius: CGFloat) {
        self.radius = radius
    }

    func shapePath() -> CGPath {
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
