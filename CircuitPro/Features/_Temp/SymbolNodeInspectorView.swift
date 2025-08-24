// In SymbolNodeInspectorView.swift

import SwiftUI
import SwiftDataPacks

struct SymbolNodeInspectorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    @PackManager private var packManager
    
    let component: DesignComponent
    @Bindable var symbolNode: SymbolNode
    
    private var referenceDesignatorBinding: Binding<String> {
        Binding(
            get: {
                // The getter is simple: just return the current computed string.
                return component.referenceDesignator
            },
            set: { newValue in
                // The setter contains the parsing and update logic.
                
                // a. Get the prefix (e.g., "R", "C") from the component definition.
                let prefix = component.definition.referenceDesignatorPrefix
                
                // b. Guard against bad input: ensure the new value starts with the correct prefix.
                guard newValue.hasPrefix(prefix) else {
                    // If the user deletes or changes the prefix, we reject the edit for now.
                    // The TextField will snap back to the previous valid value.
                    return
                }
                
                // c. Extract the number part of the string.
                let indexString = newValue.dropFirst(prefix.count)
                
                // d. Try to convert the number part to an Integer.
                guard let newIndex = Int(indexString) else {
                    // The part after the prefix is not a valid number. Reject the edit.
                    return
                }
                
                // e. Call the dedicated update method on the project manager.
                projectManager.updateReferenceDesignator(
                    for: component,
                    newIndex: newIndex,
                    using: packManager
                )
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text(component.referenceDesignator)
                    .font(.headline)
                Text(component.definition.name)
                    .foregroundColor(.secondary)
                
            }
            InspectorSection("Identity") {
                InspectorRow("Reference Designator", style: .leading) {
                    TextField(component.definition.referenceDesignatorPrefix + "?", text: referenceDesignatorBinding)
                        .inspectorField()
                    
                    
                }
            }
            
            InspectorSection("Transform") {
                PointControlView(
                    title: "Position",
                    point: $symbolNode.instance.position
                )
                
                RotationControlView(object: $symbolNode.instance)
            }
            
            InspectorSection("Properties") {
                // This ForEach block is now corrected
                ForEach(component.displayedProperties, id: \.self) { property in
                    
                    let (isVisible, onToggleVisibility) = calculateVisibility(for: property)
                    
                    // Now we create the view once, with the correct state.
                    EditablePropertyView(
                        property: property,
                        isVisible: isVisible,
                        onToggleVisibility: onToggleVisibility,
                        onSave: { updatedProperty in
                            projectManager.updateProperty(
                                for: component,
                                with: updatedProperty,
                                using: packManager
                            )
                        }
                    )
                }
            }
        }
        .environment(\.inspectorLabelColumnWidth, 60)
    }
    
    /// A helper function to determine the visibility state and action for a given property.
    /// This keeps the body of the ForEach clean.
    private func calculateVisibility(for property: Property.Resolved) -> (isVisible: Bool, onToggle: () -> Void) {
        
        // 1. We must have a definition-based property to toggle its visibility.
        guard case .definition(let propertyDefID) = property.source else {
            // This is an ad-hoc property. It cannot be toggled via dynamic text.
            // Return a "disabled" state: not visible, and the toggle action does nothing.
            return (isVisible: false, onToggle: {})
        }
        
        // 2. If it is a definition-based property, check if it's currently visible
        // by looking at the authoritative list on the SymbolNode.
        let isCurrentlyVisible = symbolNode.resolvedTexts.contains { resolvedText in
            if case .dynamic(.property(let textPropertyID)) = resolvedText.contentSource {
                return textPropertyID == propertyDefID
            }
            return false
        }
        
        // 3. Define the action to perform when the toggle button is pressed.
        let toggleAction = {
            projectManager.togglePropertyVisibility(
                for: component,
                property: property, using: packManager
            )
        }
        
        // 4. Return the calculated state and the corresponding action.
        return (isVisible: isCurrentlyVisible, onToggle: toggleAction)
    }
}
