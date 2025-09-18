//
//  InspectorValueColumn.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/27/25.
//

import SwiftUI

struct InspectorValueColumn: View {
    
    @Binding var property: Property.Resolved
    
    // Local state to buffer the user's input. This is the key to breaking the cycle.
    @State private var editedValue: String = ""
    @State private var editedMinValue: String = ""
    @State private var editedMaxValue: String = ""
    
    // Focus state to detect when the user is done editing.
    @FocusState private var focusedField: FocusableField?
    private enum FocusableField: Hashable {
        case single, min, max
    }

    var body: some View {
        HStack {
            if property.key.allowedValueType == .single {
                TextField("Value", text: $editedValue)
                    .focused($focusedField, equals: .single)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            } else {
                HStack {
                    TextField("Min", text: $editedMinValue)
                        .focused($focusedField, equals: .min)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                    
                    Text("-").foregroundStyle(.secondary)
                    
                    TextField("Max", text: $editedMaxValue)
                        .focused($focusedField, equals: .max)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        // When the view first appears, sync local state from the model.
        .onAppear(perform: initializeState)
        // When the user submits (e.g., presses Enter), commit the change.
        .onSubmit(commitChange)
        // When the focus changes (e.g., user taps away), commit the change.
        .onChange(of: focusedField) { oldFocus, newFocus in
            if oldFocus != nil && newFocus == nil { // Was focused, now is not
                commitChange()
            }
        }
        // If the underlying model changes from another source, update our local state.
        .onChange(of: property.value) {
            // Only update if we aren't the one actively editing.
            if focusedField == nil {
                initializeState()
            }
        }
    }
    
    /// Sets the local string state from the property model.
    private func initializeState() {
        switch property.value {
        case .single(let val):
            self.editedValue = val?.description ?? ""
        case .range(let minVal, let maxVal):
            self.editedMinValue = minVal?.description ?? ""
            self.editedMaxValue = maxVal?.description ?? ""
        }
    }

    /// Parses the local string state and updates the binding to the model.
    private func commitChange() {
        var newPropertyValue: PropertyValue
        
        switch property.key.allowedValueType {
        case .single:
            let numericValue = Double(editedValue)
            newPropertyValue = .single(numericValue)
            
        case .range:
            let numericMin = Double(editedMinValue)
            let numericMax = Double(editedMaxValue)
            newPropertyValue = .range(min: numericMin, max: numericMax)
        }
        
        // Only update the model if the value has actually changed.
        guard newPropertyValue != property.value else { return }
        
        // This is the ONLY time we write back to the parent.
        property.value = newPropertyValue
    }
}
