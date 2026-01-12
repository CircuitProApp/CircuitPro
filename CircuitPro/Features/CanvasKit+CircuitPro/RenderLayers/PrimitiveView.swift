import AppKit

struct PrimitiveView: CKView {
    @CKContext var context
    let primitive: AnyCanvasPrimitive

    var showHalo: Bool {
        context.highlightedItemIDs.contains(primitive.id) ||
            context.selectedItemIDs.contains(primitive.id)
    }

    var body: some CKView {
        CKGroup {
            switch primitive {
            case .rectangle(let rect):
                CKRectangle(cornerRadius: rect.shape.cornerRadius)
                    .frame(width: rect.shape.size.width, height: rect.shape.size.height)
            case .circle(let circle):
                CKCircle(radius: circle.shape.radius)

            case .line(let line):
                CKLine(length: line.shape.length, direction: .horizontal)

            }
        }
        .position(primitive.position)
        .rotation(primitive.rotation)
        .fill(primitive.filled ? primitive.color?.cgColor ?? .white : .clear)
        .stroke(primitive.color?.cgColor ?? .white, width: primitive.strokeWidth)
        .halo(showHalo ? CGColor.white.copy(alpha: 0.4) ?? .clear : .clear, width: 5.0)
    }
}
