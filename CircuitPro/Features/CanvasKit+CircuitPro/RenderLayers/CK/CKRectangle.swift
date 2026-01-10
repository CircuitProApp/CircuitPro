import AppKit

struct CKRectangle: CKShape {
    var cornerRadius: CGFloat = 0
    var style: CKStyle = .init()

    init(cornerRadius: CGFloat = 0) {
        self.cornerRadius = cornerRadius
    }

    func shapePath() -> CGPath {
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
