//
//  TextTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelize on 7/24/25.
//

import SwiftUI

struct TextTool: CanvasTool {

    
    var id: String = "text-tool"
    var symbolName: String = CircuitProSymbols.Text.textBox
    var label: String = "Text"

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        let newTextElement = TextElement(
            id: UUID(),
            text: "text",
            position: location,
            isEditable: false
        )
        
        let newAnchoredText = AnchoredTextElement(id: .init(), textElement: newTextElement, anchorPosition: location, anchorOwnerID: .init(), sourceDataID: .init(), isFromDefinition: false)
        return .element(.text(newTextElement))
    }

    mutating func handleEscape() -> Bool {
        false
    }
}
