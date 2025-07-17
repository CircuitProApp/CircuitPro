//
//  PinTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

struct PinTool: CanvasTool {

    let id = "pin"
    let symbolName = CircuitProSymbols.Symbol.pin
    let label = "Pin"

    private var rotation: CardinalRotation = .deg0

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        let number = context.existingPinCount + 1
        let pin = Pin(
            name: "",
            number: number,
            position: location,
            cardinalRotation: rotation,
            type: .unknown,
            lengthType: .long
        )
        return .element(.pin(pin))
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        let previewPin = Pin(
            name: "",
            number: context.existingPinCount + 1,
            position: mouse,
            cardinalRotation: rotation,
            type: .unknown,
            lengthType: .long
        )

        previewPin.draw(
            in: ctx,
            selected: false     // no selection halo for preview
        )
    }

    mutating func handleRotate() {
        let all = CardinalRotation.allCases
        if let idx = all.firstIndex(of: rotation) {
            rotation = all[(idx + 1) % all.count]
        }
    }
}
