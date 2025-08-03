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
            ScrollView {
                // Section for Pins
                ForEach($manager.elements) { $element in
                    if case .pin(let pin) = element, manager.selectedElementIDs.contains(pin.id) {
                        // Safely unwrap the binding to the pin
                        if let pinBinding = $element.pin {
                     
                            PinPropertiesView(pin: pinBinding)
                            
                        }
                    } else if case .primitive(let primitive) = element, manager.selectedElementIDs.contains(primitive.id) {
                        // Safely unwrap the binding to the primitive
                        if let primitiveBinding = $element.primitive {
                         
                            PrimitivePropertiesView(primitive: primitiveBinding)
                            
                        }
                    } else if case .text(let text) = element, manager.selectedElementIDs.contains(text.id) {
                        if let textBinding = $element.text {
                            
                            TextPropertiesView(textElement: textBinding, editor: manager)
                            
                        }
                    }
                }
            }
        }
    }
}
