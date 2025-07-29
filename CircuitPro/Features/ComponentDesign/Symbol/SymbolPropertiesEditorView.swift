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

import SwiftUI

// This extension allows you to get bindings to the associated values of an enum.
extension Binding where Value == CanvasElement {
    var pin: Binding<Pin>? {
        guard case .pin = self.wrappedValue else { return nil }
        return Binding<Pin>(
            get: {
                guard case .pin(let value) = self.wrappedValue else {
                    fatalError("Cannot get non-pin value as a Pin")
                }
                return value
            },
            set: {
                self.wrappedValue = .pin($0)
            }
        )
    }

    var primitive: Binding<AnyPrimitive>? {
        guard case .primitive = self.wrappedValue else { return nil }
        return Binding<AnyPrimitive>(
            get: {
                guard case .primitive(let value) = self.wrappedValue else {
                    fatalError("Cannot get non-primitive value as an AnyPrimitive")
                }
                return value
            },
            set: {
                self.wrappedValue = .primitive($0)
            }
        )
    }
    
    var pad: Binding<Pad>? {
        guard case .pad = self.wrappedValue else { return nil }
        return Binding<Pad>(
            get: {
                guard case .pad(let value) = self.wrappedValue else {
                    // This fatalError is for programmer-error, it should not happen in correct usage.
                    fatalError("Cannot get non-pad value as a Pad")
                }
                return value
            },
            set: {
                self.wrappedValue = .pad($0)
            }
        )
    }
    
}
