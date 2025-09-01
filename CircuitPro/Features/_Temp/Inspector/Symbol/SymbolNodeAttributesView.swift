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
    
    // This binding is complex, but its logic correctly finds the edited property
    // and calls the manager to handle the update. No changes are needed here.
    private var propertiesBinding: Binding<[Property.Resolved]> {
        Binding(
            get: {
                return component.displayedProperties
            },
            set: { newPropertiesArray in
                guard let componentDefinition = component.definition else { return }

                for (index, newProperty) in newPropertiesArray.enumerated() {
                    let oldProperty = component.displayedProperties[index]
                    
                    let valueChanged = (newProperty.value != oldProperty.value)
                    let unitChanged = (newProperty.unit.prefix != oldProperty.unit.prefix)

                    if valueChanged || unitChanged {
                        projectManager.updateProperty(for: component, with: newProperty)
                        break
                    }
                }
            }
        )
    }
    
    private var refdesIndexBinding: Binding<Int> {
        Binding(
            get: {
                self.component.referenceDesignatorIndex
            },
            set: { newIndex in
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
                // Binding directly to the observable instance on the node is correct.
                PointControlView(
                    title: "Position",
                    point: $symbolNode.instance.position
                )
                
                RotationControlView(object: $symbolNode.instance)
            }
            Divider()
            
            InspectorSection("Properties") {
                VStack(spacing: 0) {
                    // This Table now correctly binds to the properties.
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
                    // The toolbar for adding/removing properties is commented out for now.
                }
                .frame(height: 220)
                .clipAndStroke(with: .rect(cornerRadius: 8))
            }
        }
        .onChange(of: component) {
            // This is a correct way to ensure canvas redraws on model changes.
            symbolNode.onNeedsRedraw?()
        }
    }

    // --- REMOVED ---
    // The `calculateVisibility` function has been removed.
    // 1. It relied on the now-deleted `symbolNode.resolvedTexts` property.
    // 2. The `Table` UI does not provide a natural place to display the visibility
    //    toggle that this function would control. This function is dead code
    //    left over from a previous UI implementation. A feature to toggle property
    //    visibility would now need to be implemented differently (e.g., a context menu).
}
