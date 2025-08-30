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
    
    @Bindable var component: ComponentInstance
    @Bindable var symbolNode: SymbolNode
    
    @State private var selectedProperty: Property.Resolved.ID?
    
    @State private var viewFrame: CGSize = .zero
    
    private var propertiesBinding: Binding<[Property.Resolved]> {
        Binding(
            get: {
                // The getter is correct.
                return component.displayedProperties
            },
            set: { newPropertiesArray in
                // We need to find which property actually changed.
                // It's safer to assume only one property changes at a time in a Table.
                guard let componentDefinition = component.definition else { return }

                for (index, newProperty) in newPropertiesArray.enumerated() {
                    // It's crucial to compare against the original state, not the computed property.
                    let oldProperty = component.displayedProperties[index]
                    
                    // --- THE FIX ---
                    // Compare the actual editable values, not the stable ID.
                    let valueChanged = (newProperty.value != oldProperty.value)
                    let unitChanged = (newProperty.unit.prefix != oldProperty.unit.prefix)

                    if valueChanged || unitChanged {
                        // We found the property that was edited.
                        // Now, tell the ProjectManager to handle it.
                        projectManager.updateProperty(
                            for: component,
                            with: newProperty
                        )
                        // Since we found the change, we can stop searching.
                        break
                    }
                }
            }
        )
    }
    
    private var refdesIndexBinding: Binding<Int> {
        Binding(
            get: {
                // Read the value directly from the model
                self.component.referenceDesignatorIndex
            },
            set: { newIndex in
                // On change, call the manager's function to handle the update and redraw
                projectManager.updateReferenceDesignator(for: self.component, newIndex: newIndex)
            }
        )
    }

    
    var body: some View {
        VStack(spacing: 5) {
            InspectorSection("Identity") {
                InspectorRow("Name") {
                    Text(component.definition?.name ?? "n/a")
                        .foregroundStyle(.secondary)
                }
                InspectorRow("Refdes", style: .leading) {
                    InspectorNumericField(
                        label: component.definition?.referenceDesignatorPrefix,
                        value: refdesIndexBinding,
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
        .onChange(of: component) { oldValue, newValue in
            symbolNode.onNeedsRedraw?()
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
                property: property
            )
        }
        
        return (isVisible: isCurrentlyVisible, onToggle: toggleAction)
    }
}
