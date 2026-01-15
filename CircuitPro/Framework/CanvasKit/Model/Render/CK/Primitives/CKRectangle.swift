import AppKit

struct CKRectangle: CKView {
    var size: CGSize
    var cornerRadius: CGFloat = 0

    init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 0) {
        self.size = CGSize(width: width, height: height)
        self.cornerRadius = cornerRadius
    }

    init(size: CGSize, cornerRadius: CGFloat = 0) {
        self.size = size
        self.cornerRadius = cornerRadius
    }

    init(cornerRadius: CGFloat = 0) {
        self.size = .zero
        self.cornerRadius = cornerRadius
    }

}

extension CKRectangle: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        CKRenderNode(
            geometry: .path { _ in
                let origin = CGPoint(x: -size.width * 0.5, y: -size.height * 0.5)
                let rect = CGRect(origin: origin, size: size)
                return CGPath(
                    roundedRect: rect,
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                )
            }
        )
    }
}
