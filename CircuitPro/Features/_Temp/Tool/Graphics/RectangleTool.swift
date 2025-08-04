import SwiftUI
import AppKit

struct RectangleTool: CanvasTool {

    let id = "rectangle"
    let symbolName = CircuitProSymbols.Graphic.rectangle // Assuming  resolves in your project
    let label = "Rectangle"

    private var start: CGPoint?
    
    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        if let startPoint = start {
            // This is the second click, which finalizes the rectangle.
            let rect = CGRect(origin: startPoint, size: .zero).union(CGRect(origin: location, size: .zero))
            
            // 1. Create the data model for the primitive.
            let primitive = RectanglePrimitive(
                id: UUID(),
                size: rect.size,
                cornerRadius: 0,
                position: CGPoint(x: rect.midX, y: rect.midY), // Position is the center
                rotation: 0,
                strokeWidth: 1,
                filled: false,
                color: SDColor(color: .blue) // Using a default color
            )
            
            // 2. Wrap the primitive data in a scene graph node.
            let node = PrimitiveNode(primitive: .rectangle(primitive))

            // 3. Reset the tool's internal state.
            self.start = nil
            
            // 4. Return the new node to be added to the scene.
            return .newNode(node)
            
        } else {
            // This is the first click; just record the starting point.
            self.start = location
            return .noResult
        }
    }

    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        guard let startPoint = start else { return [] }
        
        // 1. Calculate the rectangle's frame directly in world coordinates.
        let worldRect = CGRect(origin: startPoint, size: .zero).union(CGRect(origin: mouse, size: .zero))
        
        // 2. Create a simple path from this world-coordinate rectangle.
        let path = CGPath(rect: worldRect, transform: nil)

        // 3. Return the drawing parameters. The PreviewRenderLayer will draw this path as-is.
        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.8).cgColor,
            lineDashPattern: [4, 4] // Dashed line for a preview look
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
        // For a simple two-click tool, backspace does the same as escape.
        start = nil
    }
}
