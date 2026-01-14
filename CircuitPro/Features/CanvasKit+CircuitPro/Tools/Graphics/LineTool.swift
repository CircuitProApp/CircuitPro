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

            // 1. Create the line using the new convenience initializer.
            //    All the complex math is now cleanly encapsulated in the model itself.
            let line = CanvasLine(
                start: startPoint,
                end: location,
                strokeWidth: 1.0,
                layerId: context.activeLayerId
            )

            // 2. Reset tool state and return the new primitive.
            self.start = nil
            return .newItem(AnyCanvasPrimitive.line(line))

        } else {
            // First tap: Record the start point.
            self.start = location
            return .noResult
        }
    }

    override func preview(
        mouse: CGPoint,
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) -> CKGroup {
        guard let startPoint = start else { return CKGroup() }

        // Create the rubber-band path for the preview.
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: mouse)

        let previewColor = context.layers.first { $0.id == context.activeLayerId }?.color ?? NSColor.systemBlue.withAlphaComponent(0.8).cgColor


        return CKGroup {
            CKPath(path: path)
                .stroke(previewColor, width: 1.0)
                .lineDash([4, 4])
        }
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
