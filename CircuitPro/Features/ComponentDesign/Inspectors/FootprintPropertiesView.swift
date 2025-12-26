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
               let binding = footprintEditor.padBinding(for: selection.id.rawValue) {
                PadPropertiesView(pad: binding)
            } else if let element = footprintEditor.singleSelectedNode,
                      let textNode = element as? TextNode {
                // TextPropertiesView will also use the manager from the environment
                // to resolve bindings and other contextual data.
                TextPropertiesView(textNode: textNode)
            } else if let selection = footprintEditor.singleSelectedPrimitive,
                      let binding = footprintEditor.primitiveBinding(for: selection.id.rawValue) {
                PrimitivePropertiesView(primitive: binding)
            }  else {
                Text(footprintEditor.selectedElementIDs.isEmpty ? "No Selection" : "Multiple Selection")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}
