import SwiftUI
import AppKit

/// A stateful tool for drawing lines by defining a start and end point.
final class LineTool: CanvasTool {

    // MARK: - State

    /// Stores the starting point of the line after the first tap.
    private var start: CGPoint?

    // MARK: - Overridden Properties

    override var symbolName: String { CircuitProSymbols.Graphic.line }
    override var label: String { "Line" }

    // MARK: - Overridden Methods

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        if let startPoint = self.start {
            // Second tap: Finalize the line.
            
            // 1. Create the primitive data model, preserving the original signature.
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
            // First tap: Record the start point.
            self.start = location
            return .noResult
        }
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        guard let startPoint = start else { return [] }

        // Create the rubber-band path for the preview.
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
