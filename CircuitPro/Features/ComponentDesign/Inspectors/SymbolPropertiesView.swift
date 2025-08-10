//
//  SymbolPropertiesView.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import SwiftUI

struct SymbolPropertiesView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager

    var body: some View {
        @Bindable var manager = componentDesignManager.symbolEditor
    
        VStack {
            // Using a ScrollView is a good idea for when properties get long.
            ScrollView {
                // Use the new computed property to check the selection state.
                if let element = manager.singleSelectedElement {
                    // We have exactly one selected element. Now, find out what it is.
                    
                    // --- Case 1: The selected element is a PinNode ---
                    if let pinNode = element as? PinNode {
                        @Bindable var pinNode = pinNode
                        // Pass the fresh binding to the properties view.
                        PinPropertiesView(pin: $pinNode.pin)
                        
                    // --- Case 2: The selected element is a PrimitiveNode ---
                    } else if let primitiveNode = element as? PrimitiveNode {
                        // Create a custom binding directly to the primitive data inside the node.
                        @Bindable var primitiveNode = primitiveNode
                        
                        PrimitivePropertiesView(primitive: $primitiveNode.primitive)

                    // --- Case 3 (Future): The selected element is a TextNode ---
                    } else if let textNode = element as? TextNode {
                        @Bindable var textNode = textNode
                        
                        TextPropertiesView(textElement: $textNode.textModel, editor: manager)
                        
                    } else {
                        // Add other `else if let ... as? ...` blocks here for other node types.
                        Text("Properties for this element type are not yet implemented.")
                            .padding()
                    }

                } else {
                    // This is shown for no selection or multi-selection.
                    Text(manager.selectedElementIDs.isEmpty ? "No Selection" : "Multiple Selection")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
}
