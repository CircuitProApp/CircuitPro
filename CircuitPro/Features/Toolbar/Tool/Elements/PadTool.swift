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

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        let number = context.existingPadCount + 1
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

    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> [DrawingParameters] {
        let number = context.existingPadCount + 1
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
        let all = CardinalRotation.allCases
        if let idx = all.firstIndex(of: rotation) {
            rotation = all[(idx + 1) % all.count]
        }
    }
}
