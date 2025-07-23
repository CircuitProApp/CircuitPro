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

    private var rotation: CardinalRotation = .west

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

    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> [DrawingParameters] {
        let previewPin = Pin(
            name: "",
            number: context.existingPinCount + 1,
            position: mouse,
            cardinalRotation: rotation,
            type: .unknown,
            lengthType: .long
        )

        return previewPin.makeBodyParameters()
    }

    mutating func handleRotate() {
        let all = CardinalRotation.allCases
        if let idx = all.firstIndex(of: rotation) {
            rotation = all[(idx + 1) % all.count]
        }
    }
}
