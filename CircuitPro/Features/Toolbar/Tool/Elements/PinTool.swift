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

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        let number = context.existingPinCount + 1
        let pin = Pin(
            name: "",
            number: number,
            position: location,
            type: .unknown,
            lengthType: .long
        )
        return .pin(pin)
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        let previewPin = Pin(
            name: "",
            number: context.existingPinCount + 1,
            position: mouse,
            type: .unknown,
            lengthType: .long
        )

        previewPin.draw(
            in: ctx,
            selected: false     // no selection halo for preview
        )
    }
}
