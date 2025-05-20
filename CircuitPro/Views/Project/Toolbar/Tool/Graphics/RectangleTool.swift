import SwiftUI

struct RectangleTool: CanvasTool {
    var id = "rectangle"
    var symbolName = AppIcons.rectangle
    var label = "Rectangle"

    private var start: CGPoint?

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        if let s = start {
            let rect = CGRect(origin: s, size: .zero).union(CGRect(origin: location, size: .zero))
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let size = CGSize(width: rect.width, height: rect.height)

            let prim = RectanglePrimitive(
                uuid: UUID(),
                position: center,
                size: size,
                rotation: 0,
                strokeWidth: 1,
                color: .init(color: context.selectedLayer.defaultColor),
                filled: false
            )
            start = nil
            return .primitive(.rectangle(prim))
        } else {
            start = location
            return nil
        }
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard let s = start else { return }
        let rect = CGRect(origin: s, size: .zero).union(CGRect(origin: mouse, size: .zero))

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(context.selectedLayer.defaultColor).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4])
        ctx.stroke(rect)
        ctx.restoreGState()
    }
}
