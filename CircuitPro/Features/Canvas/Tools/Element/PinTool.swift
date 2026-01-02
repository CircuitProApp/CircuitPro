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
        return .command(
            CanvasToolCommand { interactionContext, _ in
                let graph = interactionContext.renderContext.graph
                if let itemsBinding = interactionContext.renderContext.environment.items {
                    var items = itemsBinding.wrappedValue
                    let component = CanvasPin(
                        pin: pin,
                        ownerID: nil,
                        ownerPosition: .zero,
                        ownerRotation: 0,
                        layerId: nil,
                        isSelectable: true
                    )
                    items.append(component)
                    itemsBinding.wrappedValue = items
                    return
                }
                let component = CanvasPin(
                    pin: pin,
                    ownerID: nil,
                    ownerPosition: .zero,
                    ownerRotation: 0,
                    layerId: nil,
                    isSelectable: true
                )
                let nodeID = NodeID(GraphPinID.makeID(ownerID: nil, pinID: pin.id))
                if !graph.nodes.contains(nodeID) {
                    graph.addNode(nodeID)
                }
                graph.setComponent(component, for: nodeID)
            })
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        // 1. Create a temporary pin model to represent the preview.
        // Its position can be .zero since we are describing it in a local space.
        let number = nextPinNumber(in: context)
        let previewPin = Pin(
            name: "", number: number, position: .zero, cardinalRotation: rotation, type: .unknown,
            lengthType: .regular)

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

    private func nextPinNumber(in context: RenderContext) -> Int {
        let itemNumbers = context.items.compactMap { item -> Int? in
            guard let pin = item as? CanvasPin else { return nil }
            return pin.pin.number
        }
        if let maxItem = itemNumbers.max() {
            return maxItem + 1
        }

        let graph = context.graph
        let graphNumbers = graph.components(CanvasPin.self).map { $0.1.pin.number }
        return graphNumbers.max().map { $0 + 1 } ?? 1
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
