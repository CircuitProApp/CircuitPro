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
