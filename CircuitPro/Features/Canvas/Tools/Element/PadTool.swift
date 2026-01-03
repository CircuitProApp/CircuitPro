//
//  PadTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/16/25.
//

import SwiftUI

/// A stateful tool for placing pads on the canvas.
final class PadTool: CanvasTool {

    // MARK: - State

    /// The cardinal rotation for the next pad to be placed.
    private var rotation: CardinalRotation = .east

    // Note: In the future, you could add more state here to control the type
    // of pad being placed (e.g., shape, size, type), which could be set
    // via a tool properties panel in the UI.
    private var shape: PadShape = .rect(width: 5, height: 10)
    private var type: PadType = .surfaceMount
    private var drillDiameter: Double? = nil

    // MARK: - Overridden Properties

    override var symbolName: String { CircuitProSymbols.Footprint.pad } // Assumed from original code
    override var label: String { "Pad" }

    // MARK: - Overridden Methods

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        // 1. Create the Pad data model with the tool's current state.
        let number = nextPadNumber(in: context.renderContext)
        let pad = Pad(
            number: number,
            position: location,
            cardinalRotation: rotation,
            shape: shape,
            type: type,
            drillDiameter: drillDiameter
        )

        return .newItem(pad)
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        // 1. Create a temporary Pad model to generate its local-space geometry.
        // Its position is .zero because we only care about its shape relative to its own center.
        let number = nextPadNumber(in: context)
        let previewPad = Pad(
            number: number,
            position: .zero,
            shape: shape,               // Assuming `shape` is a state property of the tool
            type: type,                 // Assuming `type` is a state property of the tool
            drillDiameter: drillDiameter
        )

        // 2. Get the pad's composite path in its local coordinate space.
        let localPath = previewPad.calculateCompositePath()
        guard !localPath.isEmpty else { return [] }

        // 3. Create a transform to move the local path to the mouse cursor's world position.
        var transform = CGAffineTransform(translationX: mouse.x, y: mouse.y)
        guard let worldPath = localPath.copy(using: &transform) else {
            return []
        }

        // 4. Define the preview's appearance.
        let copperColor = NSColor.systemRed.withAlphaComponent(0.8).cgColor

        // 5. Return a single .fill primitive using the final, world-space path.
        return [.fill(path: worldPath, color: copperColor)]
    }
    override func handleEscape() -> Bool {
        // Return false to indicate the tool should remain active.
        return false
    }

    override func handleRotate() {
        // Cycle through the four cardinal directions.
        let cardinalDirections: [CardinalRotation] = [.east, .north, .west, .south]
        if let currentIndex = cardinalDirections.firstIndex(of: rotation) {
            rotation = cardinalDirections[(currentIndex + 1) % cardinalDirections.count]
        } else {
            // Default to east if the current rotation isn't a cardinal one.
            rotation = .east
        }
    }

    private func nextPadNumber(in context: RenderContext) -> Int {
        let itemNumbers = context.items.compactMap { item -> Int? in
            guard let pad = item as? Pad else { return nil }
            return pad.number
        }
        if let maxItem = itemNumbers.max() {
            return maxItem + 1
        }
        return 1
    }
}
