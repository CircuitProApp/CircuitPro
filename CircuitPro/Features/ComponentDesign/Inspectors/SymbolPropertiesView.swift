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
                        // Create a custom binding directly to the pin data inside the node.
                        let pinBinding = Binding<Pin>(
                            get: {
                                // The `if let` above guarantees this cast will succeed.
                                pinNode.pin
                            },
                            set: { newPinValue in
                                // When the UI changes the value, update the model in the array.
                                pinNode.pin = newPinValue
                                // Tell the canvas that this node needs to be redrawn.
                                pinNode.onNeedsRedraw?()
                            }
                        )
                        // Pass the fresh binding to the properties view.
                        PinPropertiesView(pin: pinBinding)
                        
                    // --- Case 2: The selected element is a PrimitiveNode ---
                    } else if let primitiveNode = element as? PrimitiveNode {
                        // Create a custom binding directly to the primitive data inside the node.
                        let primitiveBinding = Binding<AnyPrimitive>(
                            get: {
                                primitiveNode.primitive
                            },
                            set: { newPrimitiveValue in
                                primitiveNode.primitive = newPrimitiveValue
                  
                                primitiveNode.onNeedsRedraw?()
                            }
                        )
                        PrimitivePropertiesView(primitive: primitiveBinding)

                    // --- Case 3 (Future): The selected element is a TextNode ---
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
