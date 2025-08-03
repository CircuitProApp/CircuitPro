//  PadTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/16/25.
//

import SwiftUI

struct PadTool: CanvasTool {

    let id = "pad"
    let symbolName = CircuitProSymbols.Footprint.pad
    let label = "Pad"

    private var rotation: CardinalRotation = .east

    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        let number = context.renderContext.count(where: { $0.isPad }) + 1
        let pad = Pad(
            number: number,
            position: location,
            cardinalRotation: rotation,
            shape: .rect(width: 5, height: 10),
            type: .surfaceMount,
            drillDiameter: nil
        )
        return .element(.pad(pad))
    }

    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        let number = context.count(where: { $0.isPad }) + 1
        let previewPad = Pad(
            number: number,
            position: mouse,
            cardinalRotation: rotation,
            shape: .rect(width: 5, height: 10),
            type: .surfaceMount,
            drillDiameter: nil
        )

        return previewPad.makeBodyParameters()
    }
    
    mutating func handleEscape() -> Bool {
        return false
    }

    mutating func handleRotate() {
        let cardinalDirections: [CardinalRotation] = [.east, .north, .west, .south]
        if let idx = cardinalDirections.firstIndex(of: rotation) {
            rotation = cardinalDirections[(idx + 1) % cardinalDirections.count]
        } else {
            rotation = .east // Default to east if current rotation is diagonal
        }
    }
}
