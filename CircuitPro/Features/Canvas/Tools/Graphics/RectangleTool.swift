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
            let rect = CGRect(origin: startPoint, size: .zero).union(CGRect(origin: location, size: .zero))
            
            // --- MODIFIED ---
            // Create the primitive, assigning the active layer ID from the context.
            // If `activeLayerId` is nil (e.g., in a schematic view), the primitive
            // will correctly be created as an "unlayered" element.
            let primitive = CanvasRectangle(
                id: UUID(),
                shape: RectanglePrimitive(size: rect.size, cornerRadius: 0),
                position: CGPoint(x: rect.midX, y: rect.midY),
                rotation: 0,
                strokeWidth: 1,
                filled: false,
                layerId: context.activeLayerId // Assign the active layer!
            )
            
            let node = PrimitiveNode(primitive: .rectangle(primitive))
            self.start = nil
            return .newNode(node)
            
        } else {
            self.start = location
            return .noResult
        }
    }
    
    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        guard let startPoint = start else { return [] }
        
        // Calculate the rectangle's frame for the rubber-band preview.
        let worldRect = CGRect(origin: startPoint, size: .zero).union(CGRect(origin: mouse, size: .zero))
        let path = CGPath(rect: worldRect, transform: nil)

        let previewColor = context.layers.first { $0.id == context.activeLayerId }?.color ?? NSColor.systemBlue.withAlphaComponent(0.8).cgColor

        // Return a single stroke primitive for the preview layer.
        return [.stroke(
            path: path,
            color: previewColor,
            lineWidth: 1.0,
            lineDash: [4, 4]
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
