import SwiftUI
import AppKit

struct LineTool: CanvasTool {

    let id = "line"
    let symbolName = CircuitProSymbols.Graphic.line
    let label = "Line"

    private var start: CGPoint?

    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        if let startPoint = self.start {
            // Second tap: Finalize the line.
            
            // 1. Create the primitive data model.
            let linePrimitive = LinePrimitive(
                id: UUID(),
                start: startPoint,
                end: location,
                strokeWidth: 1,
                color: .init(color: .blue)
            )
            
            // 2. Wrap it in a scene graph node.
            let node = PrimitiveNode(primitive: .line(linePrimitive))
            
            // 3. Reset tool state and return the new node.
            self.start = nil
            return .newNode(node)
            
        } else {
            // First tap: Just record the start point.
            self.start = location
            return .noResult
        }
    }

    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        guard let startPoint = start else { return [] }

        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: mouse)

        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.8).cgColor,
            lineDashPattern: [4, 4]
        )]
    }

    mutating func handleEscape() -> Bool {
        if start != nil {
            start = nil
            return true
        }
        return false
    }

    mutating func handleBackspace() {
        start = nil
    }
}
