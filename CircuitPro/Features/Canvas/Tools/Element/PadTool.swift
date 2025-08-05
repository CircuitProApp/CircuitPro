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
        let number = 1 // Placeholder for now
        let pad = Pad(
            number: number,
            position: location,
            cardinalRotation: rotation,
            shape: shape,
            type: type,
            drillDiameter: drillDiameter
        )
        
        // 2. Wrap the model in a PadNode.
        let node = PadNode(pad: pad)
        
        // 3. Return the new node to be added to the scene.
        return .newNode(node)
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        // 1. Create a temporary Pad and PadNode to generate the local-space geometry.
        let number = 1 // Placeholder
        let previewPad = Pad(
            number: number,
            position: mouse, // Tentative position
            cardinalRotation: rotation,
            shape: shape,
            type: type,
            drillDiameter: drillDiameter
        )
        let previewNode = PadNode(pad: previewPad)
        let localParameters = previewNode.makeBodyParameters()

        // 2. Create a translation transform to move the local geometry to the mouse cursor's position.
        var transform = CGAffineTransform(translationX: mouse.x, y: mouse.y)

        // 3. Map over the local drawing parameters, applying the transform to each path.
        let worldParameters = localParameters.map { params -> DrawingParameters in
            var worldParams = params
            // `copy(using:)` safely creates a new, transformed CGPath.
            worldParams.path = params.path.copy(using: &transform) ?? params.path
            return worldParams
        }

        // 4. Return the parameters with paths correctly positioned in world space for rendering the preview.
        return worldParameters
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
}
