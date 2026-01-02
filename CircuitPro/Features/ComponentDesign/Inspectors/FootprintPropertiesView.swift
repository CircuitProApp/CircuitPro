//
//  FootprintPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/28/25.
//

import SwiftUI

struct FootprintPropertiesView: View {

    @BindableEnvironment(CanvasEditorManager.self)
    private var footprintEditor

    var body: some View {

        ScrollView {
            if let selection = footprintEditor.singleSelectedPad,
               let binding = footprintEditor.padBinding(for: selection.id) {
                PadPropertiesView(pad: binding)
            } else if let selection = footprintEditor.singleSelectedText,
                      let binding = footprintEditor.textBinding(for: selection.id) {
                TextPropertiesView(textID: selection.id, text: binding)
            } else if let selection = footprintEditor.singleSelectedPrimitive,
                      let binding = footprintEditor.primitiveBinding(for: selection.id) {
                PrimitivePropertiesView(primitive: binding)
            }  else {
                Text(footprintEditor.selectedElementIDs.isEmpty ? "No Selection" : "Multiple Selection")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}
