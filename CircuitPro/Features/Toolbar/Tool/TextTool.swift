//
//  TextTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelize on 7/24/25.
//

import SwiftUI

struct TextTool: CanvasTool {
    var id: String = "text-tool"
    var symbolName: String = CircuitProSymbols.Tool.text
    var label: String = "Text"

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        let newTextElement = TextElement(
            id: UUID(),
            text: "text",
            position: location
        )
        return .element(.text(newTextElement))
    }
}
