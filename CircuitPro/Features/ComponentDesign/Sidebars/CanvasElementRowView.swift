//
//  CanvasElementRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import SwiftUI

struct CanvasElementRowView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    let element: CanvasEditorManager.ElementItem
    let editor: CanvasEditorManager

    private var componentProperties: [Property.Definition] {
        componentDesignManager.componentProperties
    }


    var body: some View {


        switch element.kind {
        case .primitive(_, let primitive):
            Label(primitive.displayName, systemImage: primitive.symbol)
        case .pin(_, let pin):
            Label("Pin \(pin.pin.number)", systemImage: CircuitProSymbols.Symbol.pin)
        case .pad(_, let pad):
            Label("Pad \(pad.pad.number)", systemImage: CircuitProSymbols.Footprint.pad)
        case .node(let node):
            switch node {
            case let textNode as TextNode:
                switch textNode.resolvedText.content {
                case .static(let text):
                    Label("\"\(text)\"", systemImage: "text.bubble.fill")

                case .componentName:
                    Label("Component Name", systemImage: "c.square.fill")

                case .componentReferenceDesignator:
                    Label("Reference Designator", systemImage: "textformat.alt")

                case .componentProperty(let definitionID, _):
                    let displayName = componentProperties.first { $0.id == definitionID }?.key.label ?? "Dynamic Property"
                    Label(displayName, systemImage: "tag.fill")
                }
            default:
                Label("Unknown Element", systemImage: "questionmark.diamond")
            }
        }

    }
}
