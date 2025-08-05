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
  
        if let pinNode = element as? PinNode {
            // If it's a PinNode, we access its `pin` data model for details.
            Label("Pin \(pinNode.pin.number)", systemImage: CircuitProSymbols.Symbol.pin)

        } else if let primitiveNode = element as? PrimitiveNode {
            // If it's a PrimitiveNode, we use the new computed properties
            // we added to get its display name and symbol.
            Label(primitiveNode.displayName, systemImage: primitiveNode.symbol)

        } else {
            // A fallback for any other node types we haven't implemented a view for yet.
            Label("Unknown Element", systemImage: "questionmark.diamond")
        }
    
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
