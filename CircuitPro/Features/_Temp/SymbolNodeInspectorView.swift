// In SymbolNodeInspectorView.swift

import SwiftUI
import SwiftDataPacks

struct SymbolNodeInspectorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    @PackManager private var packManager
    
    let component: DesignComponent
    @Bindable var symbolNode: SymbolNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text(component.referenceDesignator)
                    .font(.headline)
                Text(component.definition.name)
                    .foregroundColor(.secondary)
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
                                
                                // --- START: CORRECTED LOGIC ---
                                
                                // We will calculate the state and the action *before* creating the view.
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
                                
                                // --- END: CORRECTED LOGIC ---
                            }
                        }
        }
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
