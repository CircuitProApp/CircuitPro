import SwiftUI

struct RectangleTool: CanvasTool {

    let id = "rectangle"
    let symbolName = CircuitProSymbols.Graphic.rectangle
    let label = "Rectangle"

    private var start: CGPoint?

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        if let start {
            let rect = CGRect(origin: start, size: .zero).union(CGRect(origin: location, size: .zero))
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let size = CGSize(width: rect.width, height: rect.height)

            let rectangle = RectanglePrimitive(
                id: UUID(),
                size: size,
                cornerRadius: 0,
                position: center,
                rotation: 0,
                strokeWidth: 1,
                filled: false,
                color: .init(color: context.selectedLayer.color)
            )
            self.start = nil
            return .element(.primitive(.rectangle(rectangle)))
        } else {
            self.start = location
            return .noResult
        }
    }

    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> ToolPreview? {
        guard let start else { return nil }
        let rect = CGRect(origin: start, size: .zero).union(CGRect(origin: mouse, size: .zero))
        let path = CGPath(rect: rect, transform: nil)

        return ToolPreview(
            path: path,
            strokeColor: NSColor(context.selectedLayer.color).cgColor,
            lineWidth: 1.0,
            lineDashPattern: [4, 4]
        )
    }

    mutating func handleEscape() {
        start = nil
    }

    mutating func handleBackspace() {
        start = nil
    }
}
