//
//  FootprintPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/28/25.
//

import SwiftUI

struct FootprintPropertiesView: View {

    @Environment(ComponentDesignManager.self)
    private var componentDesignManager
    
    var body: some View {
        @Bindable var manager = componentDesignManager.footprintEditor
        
        ScrollView {
            if let element = manager.singleSelectedElement {
                if let padNode = element as? PadNode {
                    @Bindable var padNode = padNode
                    
                    PadPropertiesView(pad: $padNode.pad)

                } else if let primitiveNode = element as? PrimitiveNode {
                    @Bindable var primitiveNode = primitiveNode
                    
                    PrimitivePropertiesView(primitive: $primitiveNode.primitive)

                } else if let textNode = element as? TextNode {
                    @Bindable var textNode = textNode

                    TextPropertiesView(textModel: $textNode.textModel, editor: manager)

                } else {
                    Text("Properties for this element type are not yet implemented.")
                        .padding()
                }
            }  else {
                Text(manager.selectedElementIDs.isEmpty ? "No Selection" : "Multiple Selection")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}
