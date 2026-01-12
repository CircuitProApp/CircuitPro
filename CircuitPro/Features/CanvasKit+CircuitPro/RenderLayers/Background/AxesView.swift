import AppKit

struct AxesView: CKView {
    @CKContext var context

    var strokeWidth: CGFloat {
        1.0 / max(context.magnification, .ulpOfOne)
    }

     var body: some CKView {
        let bounds = context.canvasBounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        CKLine(length: bounds.width, direction: .horizontal)
            .position(x: center.x, y: center.y)
            .stroke(NSColor.systemRed.cgColor, width: strokeWidth)

        CKLine(length: bounds.height, direction: .vertical)
            .position(x: center.x, y: center.y)
            .stroke(NSColor.systemGreen.cgColor, width: strokeWidth)
    }
}
