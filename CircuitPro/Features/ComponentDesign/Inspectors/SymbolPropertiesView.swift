//
//  SymbolPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 28.07.25.
//

import SwiftUI

struct SymbolPropertiesView: View {

    @Environment(ComponentDesignManager.self)
    private var componentDesignManager

    var body: some View {
        @Bindable var manager = componentDesignManager.symbolEditor
    
        VStack {
            ScrollView {
                if let node = manager.singleSelectedNode {
                    if let pinNode = node as? PinNode {
                        @Bindable var pinNode = pinNode

                        PinPropertiesView(pin: $pinNode.pin)
                        
                    } else if let primitiveNode = node as? PrimitiveNode {
                        @Bindable var primitiveNode = primitiveNode
                        
                        PrimitivePropertiesView(primitive: $primitiveNode.primitive)

                    } else if let textNode = node as? TextNode {
                      
                        
                        TextPropertiesView(textNode: textNode)
                        
                    } else {
                        Text("Properties for this element type are not yet implemented.")
                            .padding()
                    }
                } else {
                    Text(manager.selectedElementIDs.isEmpty ? "No Selection" : "Multiple Selection")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
}
