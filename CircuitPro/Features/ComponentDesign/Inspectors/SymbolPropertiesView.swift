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
                   let binding = symbolEditor.pinBinding(for: selection.id) {
                    PinPropertiesView(pin: binding)
                } else if let selection = symbolEditor.singleSelectedText,
                          let binding = symbolEditor.textBinding(for: selection.id) {
                    TextPropertiesView(textID: selection.id, text: binding)
                } else if let selection = symbolEditor.singleSelectedPrimitive,
                          let binding = symbolEditor.primitiveBinding(for: selection.id) {
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
