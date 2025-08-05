import SwiftUI
import AppKit

/// A stateful tool for drawing rectangles by defining two opposite corners.
final class RectangleTool: CanvasTool {

    // MARK: - State

    /// Stores the first corner of the rectangle after the first tap.
    private var start: CGPoint?

    // MARK: - Overridden Properties

    override var symbolName: String { CircuitProSymbols.Graphic.rectangle }
    override var label: String { "Rectangle" }

    // MARK: - Overridden Methods
    
    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        if let startPoint = start {
            // Second tap: Finalize the rectangle's dimensions.
            let rect = CGRect(origin: startPoint, size: .zero).union(CGRect(origin: location, size: .zero))
            
            // 1. Create the data model for the primitive, preserving the original signature.
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
            // First tap: Record the starting point.
            self.start = location
            return .noResult
        }
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        guard let startPoint = start else { return [] }
        
        // Calculate the rectangle's frame for the rubber-band preview.
        let worldRect = CGRect(origin: startPoint, size: .zero).union(CGRect(origin: mouse, size: .zero))
        let path = CGPath(rect: worldRect, transform: nil)

        // Return the drawing parameters for the preview layer.
        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.8).cgColor,
            lineDashPattern: [4, 4]
        )]
    }

    override func handleEscape() -> Bool {
        if start != nil {
            start = nil
            return true // State was cleared.
        }
        return false // No state to clear.
    }

    override func handleBackspace() {
        // For a simple two-click tool, backspace does the same as escape.
        start = nil
    }
}
