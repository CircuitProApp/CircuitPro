import SwiftUI
import AppKit

/// A stateful tool for drawing circles by defining a center and a radius.
///
/// This class holds its own state (`center`) across multiple user interactions,
/// making it a perfect example of the class-based tool architecture.
final class CircleTool: CanvasTool {

    // MARK: - State

    /// Stores the center of the circle after the first tap.
    private var center: CGPoint?

    // MARK: - Overridden Properties

    override var symbolName: String { CircuitProSymbols.Graphic.circle }
    override var label: String { "Circle" }

    // MARK: - Overridden Methods

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        if let centerPoint = center {
            // Second tap: Define the radius and finalize the circle.
            let radius = hypot(location.x - centerPoint.x, location.y - centerPoint.y)
            
            // 1. Create the primitive data model, preserving the original signature.
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
            // This assumes your AnyPrimitive enum has a case like `.circle(CirclePrimitive)`.
            let node = PrimitiveNode(primitive: .circle(circlePrimitive))

            // 3. Reset the tool's state and return the new node.
            self.center = nil
            return .newNode(node)
            
        } else {
            // First tap: Record the center point and wait for the second tap.
            self.center = location
            return .noResult
        }
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        guard let centerPoint = center else { return [] }
        
        // Create the preview path for the rubber-band effect.
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

    override func handleEscape() -> Bool {
        if center != nil {
            center = nil
            return true // State was cleared.
        }
        return false // No state to clear.
    }

    override func handleBackspace() {
        // For a simple two-step tool, backspace does the same as escape.
        center = nil
    }
}
