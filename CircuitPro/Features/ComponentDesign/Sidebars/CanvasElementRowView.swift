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

    private var componentProperties: [Property.Definition] {
        componentDesignManager.componentProperties
    }

    var body: some View {

        switch element.kind {
        case .primitive(let primitive):
            Label(
                primitive.displayName,
                systemImage: primitive.symbol)
        case .pin(let pin):
            Label("Pin \(pin.number)", systemImage: CircuitProSymbols.Symbol.pin)
        case .pad(let pad):
            Label("Pad \(pad.number)", systemImage: CircuitProSymbols.Footprint.pad)
        case .text(let text):
            switch text.content {
            case .static(let value):
                Label("\"\(value)\"", systemImage: "text.bubble.fill")
            case .componentName:
                Label("Component Name", systemImage: "c.square.fill")
            case .componentReferenceDesignator:
                Label("Reference Designator", systemImage: "textformat.alt")
            case .componentProperty(let definitionID, _):
                let displayName =
                    componentProperties.first { $0.id == definitionID }?.key.label
                    ?? "Dynamic Property"
                Label(displayName, systemImage: "tag.fill")
            }
        }

    }
}
