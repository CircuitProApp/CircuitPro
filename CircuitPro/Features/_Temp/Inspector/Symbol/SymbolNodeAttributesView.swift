//
//  SymbolNodeAttributesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftUI
import SwiftDataPacks

struct SymbolNodeAttributesView: View {
    @Environment(\.projectManager) private var projectManager
    @PackManager private var packManager
    
    let component: DesignComponent
    @Bindable var symbolNode: SymbolNode
    
    
    // (Your referenceDesignatorBinding as it was)
    private var referenceDesignatorBinding: Binding<Int> {
        Binding(
            get: { component.instance.referenceDesignatorIndex },
            set: { newValue in
                projectManager.updateReferenceDesignator(
                    for: component, newIndex: newValue, using: packManager
                )
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 15) {
            InspectorSection("Identity") {
                InspectorRow("Name") {
                    Text(component.definition.name)
                        .foregroundStyle(.secondary)
                }
                InspectorRow("Refdes", style: .leading) {
                    InspectorNumericField(
                        label: component.definition.referenceDesignatorPrefix,
                        value: referenceDesignatorBinding,
                        placeholder: "?",
                        labelStyle: .prominent
                    )
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
                ForEach(component.displayedProperties, id: \.self) { property in
                    EditablePropertyView(
                        property: property,
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
