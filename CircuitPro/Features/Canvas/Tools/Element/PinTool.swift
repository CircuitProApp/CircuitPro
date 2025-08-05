import SwiftUI

/// A stateful tool for placing pins on the canvas.
final class PinTool: CanvasTool {

    // MARK: - State

    private var rotation: CardinalRotation = .east

    // MARK: - Overridden Properties

    override var symbolName: String { CircuitProSymbols.Symbol.pin }
    override var label: String { "Pin" }

    // MARK: - Overridden Methods

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        // This part remains correct.
        let number = 1 // Placeholder
        let pin = Pin(name: "", number: number, position: location, cardinalRotation: rotation, type: .unknown, lengthType: .long)
        let node = PinNode(pin: pin)
        return .newNode(node)
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        let number = 1 // Placeholder

        // 1. Create temporary data and a node to get the local-space geometry.
        let previewPin = Pin(name: "", number: number, position: mouse, cardinalRotation: rotation, type: .unknown, lengthType: .long)
        let previewNode = PinNode(pin: previewPin)
        let localParameters = previewNode.makeBodyParameters()
        
        // --- THIS IS THE FIX ---
        // The `localParameters` contain paths centered at (0,0). We need to
        // translate them to the current mouse position to create the world-space preview.

        // 2. Create the transform that will move the local geometry to the mouse's location.
        var transform = CGAffineTransform(translationX: mouse.x, y: mouse.y)

        // 3. Map over the local parameters, applying the transform to each path.
        let worldParameters = localParameters.map { params -> DrawingParameters in
            // Create a mutable copy to modify the path.
            var worldParams = params
            // `copy(using:)` returns a new path with the transform applied.
            worldParams.path = params.path.copy(using: &transform) ?? params.path
            return worldParams
        }
        
        // 4. Return the parameters with paths in the correct world-space for the preview.
        return worldParameters
    }
    
    override func handleEscape() -> Bool {
        return false
    }

    override func handleRotate() {
        let cardinalDirections: [CardinalRotation] = [.east, .north, .west, .south]
        if let idx = cardinalDirections.firstIndex(of: rotation) {
            rotation = cardinalDirections[(idx + 1) % cardinalDirections.count]
        } else {
            rotation = .east
        }
    }
}
