// In EditablePropertyView.swift

import SwiftUI

struct EditablePropertyView: View {
    /// The resolved property to display and edit.
    let property: Property.Resolved
    
    /// A callback to execute when the user commits a change.
    let onSave: (Property.Resolved) -> Void
    
    /// Local state to hold the string value for the TextField.
    @State private var editedValue: String = ""
    
    /// A focus state to detect when the user leaves the text field.
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(property.key.label)
                // Highlight overridden properties to give the user a visual cue.
                .foregroundColor(property.isOverridden ? .accentColor : .primary)
            
            Spacer()
            
            TextField("", text: $editedValue)
                .focused($isFocused)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(minWidth: 50)
            
            if !property.unit.description.isEmpty {
           Picker(selection: Binding(
            get: { property.unit.prefix },
            set: { newPrefix in
                commitPrefixChange(newPrefix)
            }
           )) {
               Text("-")
                   .tag(nil as SIPrefix?)
               ForEach(SIPrefix.allCases) { prefix in
                   Text(prefix.name)
                       .tag(prefix as SIPrefix?)
                 
               }
           } label: {
               Text(property.unit.description)
                   .foregroundColor(.secondary)
           }

           
               
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .onAppear { initializeState(from: property) }
        .onSubmit(commitChange) // User pressed Enter
        .onChange(of: isFocused) { newFocusValue in
            if !newFocusValue { // User tapped away
                commitChange()
            }
        }
        .onChange(of: property) { newProperty in
            // If the model changes from another source and we aren't editing, update the text field.
            if !isFocused {
                initializeState(from: newProperty)
            }
        }
    }
    
    /// Sets the initial text value from the property model.
    private func initializeState(from model: Property.Resolved) {
        self.editedValue = model.value.description
    }

    /// Called when the user commits their edit to the value.
    private func commitChange() {
        var newPropertyValue: PropertyValue?

        switch property.value {
        case .single:
            if let numericValue = Double(editedValue) {
                newPropertyValue = .single(numericValue)
            }
        default:
            print("Property type not handled for editing or parsing failed.")
        }
        
        guard let finalValue = newPropertyValue else {
            initializeState(from: property)
            return
        }
        
        guard finalValue != property.value else { return }
        
        var updatedProperty = property
        updatedProperty.value = finalValue
        
        onSave(updatedProperty)
    }

    /// Called when the user selects a new prefix from the menu.
    private func commitPrefixChange(_ newPrefix: SIPrefix?) {
        // Do nothing if the prefix hasn't changed.
        guard newPrefix != property.unit.prefix else { return }

        // Create a copy of the property and update its unit prefix.
        var updatedProperty = property
        updatedProperty.unit.prefix = newPrefix
        
        // Call the save handler to persist the change.
        onSave(updatedProperty)
    }
}

// Ensure this helper exists to visually distinguish overridden properties.
extension Property.Resolved {
    /// A convenience property to check if the value comes from an override.
    var isOverridden: Bool {
        // This is a placeholder. A real implementation would compare the resolved
        // property's values against its original definition default.
        // For now, any property associated with a definition is considered overridable.
        if case .definition = source {
            return true
        }
        return false
    }
}
