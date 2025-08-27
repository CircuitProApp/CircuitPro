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
    
    @State private var selectedProperty: Property.Resolved.ID?
    
    @State private var viewFrame: CGSize = .zero
    
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
    
    private var propertiesBinding: Binding<[Property.Resolved]> {
        Binding(
            get: {
                // GET: Simply return the computed properties of the current component.
                // If the component is gone, return an empty array.
                return component.displayedProperties
            },
            set: { newPropertiesArray in
                // SET: This is where we call the ProjectManager.
                let currentComponent = component
                
                // Find which property actually changed.
                for (index, newProperty) in newPropertiesArray.enumerated() {
                    let oldProperty = currentComponent.displayedProperties[index]
                    
                    // If a property is different from its old version...
                    if newProperty != oldProperty {
                        // ...call the existing, correct method on the ProjectManager.
                        projectManager.updateProperty(
                            for: currentComponent,
                            with: newProperty,
                            using: packManager
                        )
                        // We found the change, so we can stop looking.
                        break
                    }
                }
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
                VStack(spacing: 0) {
                    Table(propertiesBinding, selection: $selectedProperty) {
                        TableColumn("Key") { $property in
                            Text(property.key.label)
                        }
                       
                 
                        TableColumn("Value") { $property in
                            InspectorValueColumn(property: $property)
                        }
                  
                        TableColumn("Unit") { $property in
                            InspectorUnitColumn(property: $property)
                        }
                
                    }
                    .font(.caption)
                    .tableStyle(.bordered)
                    .border(.regularMaterial)
                    .onGeometryChange(for: CGSize.self, of: \.size) { newSize in
                        viewFrame = newSize
                        print("New view size: \(newSize)")
                    }

                    Divider()
                    HStack(spacing: 4) {
                        Button {
                            
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 24)
                                .contentShape(.rect)
                        }
                        Divider()
                        Button {
                            
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 24, height: 24)
                                .contentShape(.rect)
                        }
                        .disabled(selectedProperty == nil)
                        Divider()
                        Button {
                            
                        } label: {
                            Image(systemName: "pencil")
                                .frame(width: 24, height: 24)
                                .contentShape(.rect)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    .frame(height: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
                .frame(height: 220)
                .clipAndStroke(with: .rect(cornerRadius: 8))
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
