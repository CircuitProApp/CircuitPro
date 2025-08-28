//
//  TextTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelize on 7/24/25.
//

import SwiftUI

/// A tool for creating `TextNode` instances on the canvas.
class TextTool: CanvasTool {

    override var symbolName: String { CircuitProSymbols.Text.textBox }
    override var label: String {  "Text" }

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        let newTextModel = TextModel(
            id: UUID(),
            text: "Text",
            position: location, anchor: .bottomLeading
        )

        let newTextNode = TextNode(textModel: newTextModel)

        return .newNode(newTextNode)
    }

    /// Handles the Escape key. This tool has no intermediate state, so it
    /// doesn't need to do anything and can signal that the event was not handled.
    override func handleEscape() -> Bool {
        return false
    }
}
