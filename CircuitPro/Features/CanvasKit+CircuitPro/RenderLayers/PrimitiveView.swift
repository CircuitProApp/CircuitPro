import AppKit

struct PrimitiveView: CKView {
    @CKContext var context
    let primitive: AnyCanvasPrimitive
    let isEditable: Bool

    var body: some CKView {
        switch primitive {
        case .rectangle(let rect):
            RectangleView(
                rectangle: rect,
                isEditable: isEditable
            )
            .position(rect.position)
            .rotation(rect.rotation)
        case .circle(let circle):
            CircleView(
                circle: circle,
                isEditable: isEditable
            )
            .position(circle.position)
            .rotation(circle.rotation)
        case .line(let line):
            LineView(
                line: line,
                isEditable: isEditable
            )
            .position(line.position)
            .rotation(line.rotation)
        }
    }

}

extension PrimitiveView: CKHitTestable {
    func hitTestPath(in context: RenderContext) -> CGPath {
        let base = PrimitiveGeometry.localPath(for: primitive)
        guard !base.isEmpty else { return CGMutablePath() }

        var transform = CGAffineTransform(
            translationX: primitive.position.x,
            y: primitive.position.y
        )
        transform = transform.rotated(by: primitive.rotation)
        let transformed = base.copy(using: &transform) ?? base

        let padding = 4.0 / max(context.magnification, 0.001)
        let strokeWidth = max(primitive.strokeWidth, 1.0) + padding
        let stroked = transformed.copy(
            strokingWithWidth: strokeWidth,
            lineCap: .round,
            lineJoin: .miter,
            miterLimit: 10
        )

        if primitive.filled {
            let merged = CGMutablePath()
            merged.addPath(transformed)
            merged.addPath(stroked)
            return merged
        }

        return stroked
    }
}
