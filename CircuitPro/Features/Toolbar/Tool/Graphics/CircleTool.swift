import SwiftUI

struct CircleTool: CanvasTool {
    var id = "circle"
    var symbolName = AppIcons.circle
    var label = "Circle"

    private var center: CGPoint?

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        if let center {
            let radius = hypot(location.x - center.x, location.y - center.y)
            let circle = CirclePrimitive(
                id: UUID(),
                position: center,
                radius: radius,
                rotation: 0,
                strokeWidth: 1,
                color: .init(color: context.selectedLayer.defaultColor),
                filled: false
            )
            self.center = nil
            return .primitive(.circle(circle))
        } else {
            self.center = location
            return nil
        }
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard let center else { return }
        let radius = hypot(mouse.x - center.x, mouse.y - center.y)
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(context.selectedLayer.defaultColor).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4])
        ctx.strokeEllipse(in: rect)
        ctx.restoreGState()
    }
}
