import AppKit

struct CKCircle: CKView {
    var radius: CGFloat

    init(radius: CGFloat) {
        self.radius = radius
    }
}

extension CKCircle: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        CKRenderNode(
            geometry: .path { _ in
                let rect = CGRect(
                    x: -radius,
                    y: -radius,
                    width: radius * 2,
                    height: radius * 2
                )
                return CGPath(ellipseIn: rect, transform: nil)
            }
        )
    }
}
