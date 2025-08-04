//
//  CanvasElementRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import SwiftUI

struct CanvasElementRowView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    let element: any CanvasNode
    let editor: CanvasEditorManager

    private var componentProperties: [PropertyDefinition] {
        componentDesignManager.componentProperties
    }

    var body: some View {
        Text("WIP")
//        switch element {
//        case .pin(let pin):
//            Label("Pin \(pin.number)", systemImage: CircuitProSymbols.Symbol.pin)
//        case .pad(let pad):
//            Label("Pad \(pad.number)", systemImage: CircuitProSymbols.Footprint.pad)
//        case .primitive(let primitive):
//            Label(primitive.displayName, systemImage: primitive.symbol)
//        case .text(let textElement):
//            textElementRow(textElement)
//        default:
//            Text("Not Implemented")
//        }
    }

    @ViewBuilder
    private func textElementRow(_ textElement: TextElement) -> some View {
        if let source = editor.textSourceMap[textElement.id] {
            switch source {
            case .dynamic(.componentName):
                Label("Component Name", systemImage: "c.square.fill")
            case .dynamic(.reference):
                Label("Reference Designator", systemImage: "textformat.alt")
            case .dynamic(.property(let definitionID)):
                let displayName = componentProperties.first { $0.id == definitionID }?.key.label ?? "Dynamic Property"
                Label(displayName, systemImage: "tag.fill")
            case .static:
                Label("\"\(textElement.text)\"", systemImage: "text.bubble.fill")
            }
        } else {
            Label("\"\(textElement.text)\"", systemImage: "text.bubble.fill")
        }
    }
}
