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
            if let element = footprintEditor.singleSelectedNode {
                if let padNode = element as? PadNode {
                    @Bindable var padNode = padNode
                    
                    PadPropertiesView(pad: $padNode.pad)

                } else if let primitiveNode = element as? PrimitiveNode {
                    @Bindable var primitiveNode = primitiveNode
                    
                    PrimitivePropertiesView(primitive: $primitiveNode.primitive)

                } else if let textNode = element as? TextNode {
                 
                    // TextPropertiesView will also use the manager from the environment
                    // to resolve bindings and other contextual data.
                    TextPropertiesView(textNode: textNode)

                } else {
                    Text("Properties for this element type are not yet implemented.")
                        .padding()
                }
            }  else {
                Text(footprintEditor.selectedElementIDs.isEmpty ? "No Selection" : "Multiple Selection")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}
