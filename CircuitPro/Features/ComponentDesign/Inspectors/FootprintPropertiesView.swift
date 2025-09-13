//
//  FootprintPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/28/25.
//

import SwiftUI

struct FootprintPropertiesView: View {

    // The parent view (ComponentDesignStageContainerView) now places the
    // correct CanvasEditorManager for the selected footprint into the environment.
    // We retrieve it directly here.
    @Environment(CanvasEditorManager.self)
    private var manager
    
    var body: some View {
        // This @Bindable wrapper now correctly observes the manager for the selected footprint.
        @Bindable var manager = manager
        
        ScrollView {
            if let element = manager.singleSelectedNode {
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
                Text(manager.selectedElementIDs.isEmpty ? "No Selection" : "Multiple Selection")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}
