//
//  SymbolPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 28.07.25.
//

import SwiftUI

struct SymbolPropertiesView: View {

    @Environment(CanvasEditorManager.self)
    private var symbolEditor

    var body: some View {
        VStack {
            ScrollView {
                if let node = symbolEditor.singleSelectedNode {
                    if let pinNode = node as? PinNode {
                        @Bindable var pinNode = pinNode

                        PinPropertiesView(pin: $pinNode.pin)

                    } else if let textNode = node as? TextNode {


                        TextPropertiesView(textNode: textNode)

                    } else {
                        Text("Properties for this element type are not yet implemented.")
                            .padding()
                    }
                } else if let selection = symbolEditor.singleSelectedPrimitive,
                          let binding = symbolEditor.primitiveBinding(for: selection.id.rawValue) {
                    PrimitivePropertiesView(primitive: binding)
                } else {
                    Text(symbolEditor.selectedElementIDs.isEmpty ? "No Selection" : "Multiple Selection")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
}
