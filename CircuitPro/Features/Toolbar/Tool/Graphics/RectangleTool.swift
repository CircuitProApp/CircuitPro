import SwiftUI

struct RectangleTool: CanvasTool {

    let id = "rectangle"
    let symbolName = AppIcons.rectangle
    let label = "Rectangle"

    private var start: CGPoint?

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        if let start {
            let rect = CGRect(origin: start, size: .zero).union(CGRect(origin: location, size: .zero))
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let size = CGSize(width: rect.width, height: rect.height)

            let prim = RectanglePrimitive(
                id: UUID(),
                size: size,
                cornerRadius: 0,
                position: center,
                rotation: 0,
                strokeWidth: 1,
                filled: false,
                color: .init(color: context.selectedLayer.defaultColor)
            )
            self.start = nil
            return .primitive(.rectangle(prim))
        } else {
            self.start = location
            return nil
        }
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard let start else { return }
        let rect = CGRect(origin: start, size: .zero).union(CGRect(origin: mouse, size: .zero))

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(context.selectedLayer.defaultColor).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4])
        ctx.stroke(rect)
        ctx.restoreGState()
    }
}
