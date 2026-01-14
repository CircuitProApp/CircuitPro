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

    override func preview(
        mouse: CGPoint,
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) -> CKGroup {
        // Render a temporary pad view at the cursor location.
        let number = nextPadNumber(in: context)
        let previewPad = Pad(
            number: number,
            position: mouse,
            shape: shape,
            type: type,
            drillDiameter: drillDiameter
        )
        return CKGroup {
            PadView(pad: previewPad)
        }
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
