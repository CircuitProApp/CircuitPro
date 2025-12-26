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
                if let selection = symbolEditor.singleSelectedPin,
                   let binding = symbolEditor.pinBinding(for: selection.id.rawValue) {
                    PinPropertiesView(pin: binding)
                } else if let node = symbolEditor.singleSelectedNode,
                          let textNode = node as? TextNode {
                    TextPropertiesView(textNode: textNode)
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
