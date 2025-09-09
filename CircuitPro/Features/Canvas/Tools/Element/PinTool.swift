import SwiftUI

/// A stateful tool for placing pins on the canvas.
final class PinTool: CanvasTool {

    // MARK: - State

    private var rotation: CardinalRotation = .east

    // MARK: - Overridden Properties

    override var symbolName: String { CircuitProSymbols.Symbol.pin } // Assuming you have a symbol asset named this.
    override var label: String { "Pin" }

    // MARK: - Overridden Methods

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        // This method is already correct and does not need to change.
        let number = context.renderContext.sceneRoot.children
            .compactMap { $0 as? PinNode }
            .map { $0.pin.number }
            .max()
            .map { $0 + 1 } ?? 1
        let pin = Pin(name: "", number: number, position: location, cardinalRotation: rotation, type: .unknown, lengthType: .regular)
        let node = PinNode(pin: pin)
        return .newNode(node)
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        // 1. Create a temporary pin model to represent the preview.
        // Its position can be .zero since we are describing it in a local space.
        let number = context.sceneRoot.children
            .compactMap { $0 as? PinNode }
            .map { $0.pin.number }
            .max()
            .map { $0 + 1 } ?? 1
        let previewPin = Pin(name: "", number: number, position: .zero, cardinalRotation: rotation, type: .unknown, lengthType: .regular)
        
        // 2. Get the model's drawing commands in its local coordinate space.
        let localPrimitives = previewPin.makeDrawingPrimitives()
        
        // 3. Create a transform to move the local shape to the mouse cursor's world position.
        var worldTransform = CGAffineTransform(translationX: mouse.x, y: mouse.y)
        
        // 4. Map over the local primitives, applying the transform to each one to get world-space primitives.
        // This reuses the `applying(transform:)` helper, which correctly handles paths and text.
        let worldPrimitives = localPrimitives.map { primitive in
            primitive.applying(transform: &worldTransform)
        }
        
        return worldPrimitives
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
