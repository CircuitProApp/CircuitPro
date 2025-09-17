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
    
    @Query(sort: \FootprintDefinition.name) private var allFootprints: [FootprintDefinition]
    
    @State private var selectedProperty: Property.Resolved.ID?
    
    // MARK: - Computed Properties for Footprint Sections (Unchanged)
    
    private var compatibleFootprints: [FootprintDefinition] {
        component.definition?.footprints.sorted(by: { $0.name < $1.name }) ?? []
    }
    
    private var otherFootprints: [FootprintDefinition] {
        let compatibleUUIDs = Set(compatibleFootprints.map { $0.uuid })
        return allFootprints.filter { !compatibleUUIDs.contains($0.uuid) }
    }
    
    /// The display name of the currently selected footprint.
    // --- MODIFIED: This now uses the resolver ---
    private var selectedFootprintName: String {
        return projectManager.resolvedFootprintName(for: component) ?? "None"
    }

    // MARK: - Bindings

    private var propertiesBinding: Binding<[Property.Resolved]> {
        Binding(
            // --- MODIFIED: The 'get' now resolves each property individually ---
            get: {
                // Return a new array where each original property has been resolved
                // against any pending changes.
                return component.displayedProperties.compactMap { originalProperty in
                    projectManager.resolvedProperty(for: component, propertyID: originalProperty.id)
                }
            },
            set: { newPropertiesArray in
                // The 'set' logic is correct and remains unchanged.
                for newProperty in newPropertiesArray {
                    // Find the original property to check if the value actually changed.
                    if let oldProperty = component.displayedProperties.first(where: { $0.id == newProperty.id }) {
                        if newProperty.value != oldProperty.value || newProperty.unit.prefix != oldProperty.unit.prefix {
                            projectManager.updateProperty(for: component, with: newProperty)
                        }
                    }
                }
            }
        )
    }
    
    private var refdesIndexBinding: Binding<Int> {
        Binding(
            // --- MODIFIED: The 'get' now uses the resolver ---
            get: { projectManager.resolvedReferenceDesignator(for: self.component) },
            set: { newIndex in
                // The 'set' logic is correct and remains unchanged.
                projectManager.updateReferenceDesignator(for: self.component, newIndex: newIndex)
            }
        )
    }

    private var footprintBinding: Binding<UUID?> {
        Binding(
            // This was already correct from your last update!
            get: { projectManager.resolvedFootprintUUID(for: component) },
            set: { newUUID in
                if let newUUID = newUUID {
                    if let selectedFootprint = allFootprints.first(where: { $0.uuid == newUUID }) {
                        projectManager.assignFootprint(to: component, footprint: selectedFootprint)
                    }
                } else {
                    projectManager.assignFootprint(to: component, footprint: nil)
                }
            }
        )
    }
    
    // Body of the view (No changes needed here)
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            InspectorSection("Identity") {
                InspectorRow("Name") {
                    Text(component.definition?.name ?? "n/a")
                        .foregroundStyle(.secondary)
                }
                InspectorRow("Refdes", style: .leading) {
                    InspectorNumericField(
                        label: component.definition?.referenceDesignatorPrefix,
                        value: refdesIndexBinding, // This now gets the resolved value
                        placeholder: "?",
                        labelStyle: .prominent
                    )
                }
            }
            
            Divider()

            InspectorSection("Footprint") {
                InspectorRow("Assigned") {
                    Menu {
                        Button("None") {
                            footprintBinding.wrappedValue = nil
                        }
                        // ... menu sections remain the same ...
                        if !compatibleFootprints.isEmpty {
                            Section("Compatible") {
                                ForEach(compatibleFootprints) { footprint in
                                    Button(footprint.name) {
                                        footprintBinding.wrappedValue = footprint.uuid
                                    }
                                }
                            }
                        }
                        if !compatibleFootprints.isEmpty && !otherFootprints.isEmpty {
                            Divider()
                        }
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
                        Text(selectedFootprintName) // This now gets the resolved name
                    }
                    .menuStyle(.automatic)
                    .controlSize(.small)
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
                    // This table is now bound to the resolved properties array
                    Table(propertiesBinding, selection: $selectedProperty) {
                        TableColumn("Key") { $property in Text(property.key.label) }
                        TableColumn("Value") { $property in InspectorValueColumn(property: $property) }
                        TableColumn("Unit") { $property in InspectorUnitColumn(property: $property) }
                    }
                    .font(.caption)
                    .tableStyle(.bordered)
                    .border(.white.blendMode(.destinationOut), width: 1)
                    .compositingGroup()
                }
                .frame(height: 220)
                .clipAndStroke(with: .rect(cornerRadius: 8))
            }
        }
        .onChange(of: component) {
            symbolNode.onNeedsRedraw?()
        }
    }
}
