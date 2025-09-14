//
//  SymbolNodeAttributesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftUI
import SwiftData

struct SymbolNodeAttributesView: View {
    @Environment(\.projectManager) private var projectManager
    
    @Bindable var component: ComponentInstance
    @Bindable var symbolNode: SymbolNode
    
    // ADDED: Query to fetch all available footprints to populate the picker.
    @Query(sort: \FootprintDefinition.name) private var allFootprints: [FootprintDefinition]
    
    @State private var selectedProperty: Property.Resolved.ID?
    
    // MARK: - Computed Properties for Footprint Sections
    
    /// Footprints that are directly associated with the component's definition.
    private var compatibleFootprints: [FootprintDefinition] {
        component.definition?.footprints.sorted(by: { $0.name < $1.name }) ?? []
    }
    
    /// All other footprints in the library, excluding the compatible ones.
    private var otherFootprints: [FootprintDefinition] {
        let compatibleUUIDs = Set(compatibleFootprints.map { $0.uuid })
        return allFootprints.filter { !compatibleUUIDs.contains($0.uuid) }
    }
    
    /// The display name of the currently selected footprint.
    private var selectedFootprintName: String {
        guard let selectedUUID = component.footprintInstance?.definitionUUID else {
            return "None"
        }
        // Find the footprint in the full list to get its name.
        return allFootprints.first { $0.uuid == selectedUUID }?.name ?? "Invalid Footprint"
    }

    // MARK: - Bindings

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

    private var footprintBinding: Binding<UUID?> {
        Binding(
            get: {
                // The value of the picker is the UUID of the currently assigned footprint instance.
                return component.footprintInstance?.definitionUUID
            },
            set: { newUUID in
                // When the picker's value changes, this logic runs.
                if let newUUID = newUUID {
                    // If a new footprint was selected, find it in our query results.
                    if let selectedFootprint = allFootprints.first(where: { $0.uuid == newUUID }) {
                        // Tell the project manager to assign this footprint.
                        projectManager.assignFootprint(to: component, footprint: selectedFootprint)
                    }
                } else {
                    // If "None" was selected (newUUID is nil), un-assign the footprint.
                    projectManager.assignFootprint(to: component, footprint: nil)
                }
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

            // --- UPDATED: Footprint Assignment Section ---
            InspectorSection("Footprint") {
                InspectorRow("Assigned") {
                    // Replace the Picker with a more flexible Menu
                    Menu {
                        // Option to clear the selection
                        Button("None") {
                            footprintBinding.wrappedValue = nil
                        }

                        // Section 1: Compatible Footprints
                        if !compatibleFootprints.isEmpty {
                            Section("Compatible") {
                                ForEach(compatibleFootprints) { footprint in
                                    Button(footprint.name) {
                                        footprintBinding.wrappedValue = footprint.uuid
                                    }
                                }
                            }
                        }

                        // Visual separator if both sections exist
                        if !compatibleFootprints.isEmpty && !otherFootprints.isEmpty {
                            Divider()
                        }

                        // Section 2: Other Footprints
                        if !otherFootprints.isEmpty {
                            Section("Other Footprints") {
                                ForEach(otherFootprints) { footprint in
                                    Button(footprint.name) {
                                        footprintBinding.wrappedValue = footprint.uuid
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(selectedFootprintName)
                    }
                    .menuStyle(.automatic)
                    .controlSize(.small)
                }
            }
            // --- END UPDATED SECTION ---
            
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
}
