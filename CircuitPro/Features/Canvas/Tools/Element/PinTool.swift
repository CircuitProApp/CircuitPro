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
        // 1. Create a temporary pin. Its position can be .zero, as it's not used in local geometry calculations.
        let previewPin = Pin(name: "", number: 1, position: .zero, cardinalRotation: rotation, type: .unknown, lengthType: .long)
        
        // 2. Get the LOCAL drawing parameters.
        let localParameters = previewPin.makeAllBodyParameters()
        
        // 3. Create a transform to move the local geometry to the mouse's location.
        var worldTransform = CGAffineTransform(translationX: mouse.x, y: mouse.y)
        
        // 4. Map over the local parameters, applying the world transform to each path.
        return localParameters.map { params in
            var worldParams = params
            worldParams.path = params.path.copy(using: &worldTransform) ?? params.path
            return worldParams
        }
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
