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

    private var rotation: CardinalRotation = .east

    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        let number = /*context.renderContext.count(where: { $0.isPin }) +*/ 1
        let pin = Pin(
            name: "",
            number: number,
            position: location,
            cardinalRotation: rotation,
            type: .unknown,
            lengthType: .long
        )
        return .noResult
    }

    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        let number = /*context.count(where: { $0.isPin }) +*/ 1
        let previewPin = Pin(
            name: "",
            number: number,
            position: mouse,
            cardinalRotation: rotation,
            type: .unknown,
            lengthType: .long
        )

        return previewPin.makeBodyParameters()
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
