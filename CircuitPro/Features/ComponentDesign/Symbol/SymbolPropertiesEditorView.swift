//
//  SymbolPropertiesEditorView.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import SwiftUI

struct SymbolPropertiesEditorView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager

    var body: some View {
        
        @Bindable var manager = componentDesignManager
    
        VStack {
            if componentDesignManager.selectedSymbolElementIDs.isEmpty {
                placeholder("No elements selected")
            } else {
                ScrollView {
                    // Section for Pins
                    ForEach($manager.symbolElements) { $element in
                        if case .pin(let pin) = element, componentDesignManager.selectedSymbolElementIDs.contains(pin.id) {
                            // Safely unwrap the binding to the pin
                            if let pinBinding = $element.pin {
                         
                                PinPropertiesView(pin: pinBinding)
                                
                            }
                        } else if case .primitive(let primitive) = element, componentDesignManager.selectedSymbolElementIDs.contains(primitive.id) {
                            // Safely unwrap the binding to the primitive
                            if let primitiveBinding = $element.primitive {
                             
                                PrimitivePropertiesView(primitive: primitiveBinding)
                                
                            }
                        }
                    }
                }

            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
