import SwiftUI

struct CircleTool: CanvasTool {

    let id = "circle"
    let symbolName = CircuitProSymbols.Graphic.circle
    let label = "Circle"

    private var center: CGPoint?

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        if let center {
            let radius = hypot(location.x - center.x, location.y - center.y)
            let circle = CirclePrimitive(
                id: UUID(),
                radius: radius,
                position: center,
                rotation: 0,
                strokeWidth: 1,
                color: .init(color: context.selectedLayer.color),
                filled: false
            )
            self.center = nil
            return .element(.primitive(.circle(circle)))
        } else {
            self.center = location
            return .noResult
        }
    }

    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> [DrawingParameters] {
        guard let center else { return [] }
        let radius = hypot(mouse.x - center.x, mouse.y - center.y)
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let path = CGPath(ellipseIn: rect, transform: nil)

        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,
            strokeColor: NSColor(context.selectedLayer.color).cgColor,
            lineDashPattern: [4, 4]
        )]
    }

    mutating func handleEscape() -> Bool {
        defer { center = nil }
        return center != nil
    }

    mutating func handleBackspace() {
        center = nil
    }
}
