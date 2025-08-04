import SwiftUI
import AppKit

struct CircleTool: CanvasTool {

    let id = "circle"
    let symbolName = CircuitProSymbols.Graphic.circle
    let label = "Circle"

    private var center: CGPoint?

    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        if let centerPoint = center {
            // Second tap: Define the radius and finalize the circle.
            let radius = hypot(location.x - centerPoint.x, location.y - centerPoint.y)
            
            // 1. Create the primitive data model.
            let circlePrimitive = CirclePrimitive(
                id: UUID(),
                radius: radius,
                position: centerPoint,
                rotation: 0,
                strokeWidth: 1,
                color: .init(color: .blue),
                filled: false
            )

            // 2. Wrap it in a scene graph node.
            let node = PrimitiveNode(primitive: .circle(circlePrimitive))

            // 3. Reset tool state and return the new node.
            self.center = nil
            return .newNode(node)
            
        } else {
            // First tap: Just record the center point.
            self.center = location
            return .noResult
        }
    }

    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        guard let centerPoint = center else { return [] }
        
        // Create the preview path directly in world coordinates.
        let radius = hypot(mouse.x - centerPoint.x, mouse.y - centerPoint.y)
        let rect = CGRect(x: centerPoint.x - radius, y: centerPoint.y - radius, width: radius * 2, height: radius * 2)
        let path = CGPath(ellipseIn: rect, transform: nil)

        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.8).cgColor,
            lineDashPattern: [4, 4]
        )]
    }

    mutating func handleEscape() -> Bool {
        if center != nil {
            center = nil
            return true // State was cleared.
        }
        return false // No state to clear.
    }

    mutating func handleBackspace() {
        center = nil
    }
}
