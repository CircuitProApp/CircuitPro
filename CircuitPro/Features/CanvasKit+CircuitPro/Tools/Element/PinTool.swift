import SwiftUI

/// A stateful tool for placing pins on the canvas.
final class PinTool: CanvasTool {

    // MARK: - State

    private var rotation: CardinalRotation = .east

    // MARK: - Overridden Properties

    override var symbolName: String { CircuitProSymbols.Symbol.pin }  // Assuming you have a symbol asset named this.
    override var label: String { "Pin" }

    // MARK: - Overridden Methods

    override func handleTap(at location: CGPoint, context: ToolInteractionContext)
        -> CanvasToolResult
    {
        let number = nextPinNumber(in: context.renderContext)
        let pin = Pin(
            name: "", number: number, position: location, cardinalRotation: rotation,
            type: .unknown, lengthType: .regular)
        return .newItem(pin)
    }

    override func preview(
        mouse: CGPoint,
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) -> CKGroup {
        // Render a temporary pin view at the cursor location.
        let number = nextPinNumber(in: context)
        let previewPin = Pin(
            name: "", number: number, position: mouse, cardinalRotation: rotation, type: .unknown,
            lengthType: .regular)
        return CKGroup {
            PinView(pin: previewPin)
        }
    }

    private func nextPinNumber(in context: RenderContext) -> Int {
        let itemNumbers = context.items.compactMap { item -> Int? in
            guard let pin = item as? Pin else { return nil }
            return pin.number
        }
        if let maxItem = itemNumbers.max() {
            return maxItem + 1
        }
        return 1
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
