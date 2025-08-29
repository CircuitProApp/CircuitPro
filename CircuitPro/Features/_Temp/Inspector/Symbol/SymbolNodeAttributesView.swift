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
                return component.displayedProperties
            },
            set: { newPropertiesArray in
                let currentComponent = component
                
                for (index, newProperty) in newPropertiesArray.enumerated() {
                    let oldProperty = currentComponent.displayedProperties[index]
                    
                    if newProperty.id != oldProperty.id {
                        projectManager.updateProperty(
                            for: currentComponent,
                            with: newProperty,
                            using: packManager
                        )
                        break
                    }
                }
            }
        )
    }

    
    var body: some View {
        VStack(spacing: 5) {
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
            
            Divider()
            
            InspectorSection("Transform") {
                PointControlView(
                    title: "Position",
                    point: $symbolNode.instance.position
                )
                
                RotationControlView(object: $symbolNode.instance)
            }
            Divider()
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
                    .border(.white.blendMode(.destinationOut), width: 1)
                    .compositingGroup()
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
        
        guard case .definition(let propertyDefID) = property.source else {
            return (isVisible: false, onToggle: {})
        }
        
        let isCurrentlyVisible = symbolNode.resolvedTexts.contains { resolvedText in
            resolvedText.isVisible && resolvedText.contentSource == .componentProperty(definitionID: propertyDefID.id)
        }
        
        let toggleAction = {
            projectManager.togglePropertyVisibility(
                for: component,
                property: property, using: packManager
            )
        }
        
        return (isVisible: isCurrentlyVisible, onToggle: toggleAction)
    }
}
