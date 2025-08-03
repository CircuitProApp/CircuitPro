import SwiftUI

struct RectangleTool: CanvasTool {

    let id = "rectangle"
    let symbolName = CircuitProSymbols.Graphic.rectangle
    let label = "Rectangle"

    private var start: CGPoint?

    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
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
                color: .init(color: .red)
            )
            self.start = nil
            return .element(.primitive(.rectangle(rectangle)))
        } else {
            self.start = location
            return .noResult
        }
    }

    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        guard let start else { return [] }
        let rect = CGRect(origin: start, size: .zero).union(CGRect(origin: mouse, size: .zero))
        let path = CGPath(rect: rect, transform: nil)

        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,
            strokeColor: NSColor(.red).cgColor,
            lineDashPattern: [4, 4]
        )]
    }

    mutating func handleEscape() -> Bool {
        if start != nil {
            start = nil
            return true // State was cleared.
        }
        return false // No state to clear.
    }

    mutating func handleBackspace() {
        start = nil
    }
}
