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
    
    // MARK: - Computed Properties for Footprint Sections
    
    private var compatibleFootprints: [FootprintDefinition] {
        component.definition?.footprints.sorted(by: { $0.name < $1.name }) ?? []
    }
    
    private var otherFootprints: [FootprintDefinition] {
        let compatibleUUIDs = Set(compatibleFootprints.map { $0.uuid })
        return allFootprints.filter { !compatibleUUIDs.contains($0.uuid) }
    }
    
    /// The display name of the currently selected footprint.
    // --- MODIFIED: This is now more robust ---
    private var selectedFootprintName: String {
        // First, try to get the name from the hydrated definition directly. This is fast and reliable.
        if let hydratedName = component.footprintInstance?.definition?.name {
            return hydratedName
        }
        
        // If the definition isn't hydrated for some reason (e.g., during a state transition),
        // fall back to searching the full list. This makes the UI resilient.
        if let selectedUUID = component.footprintInstance?.definitionUUID {
            return allFootprints.first { $0.uuid == selectedUUID }?.name ?? "Invalid Footprint"
        }
        
        // If there's no footprint instance at all.
        return "None"
    }

    // MARK: - Bindings (No changes needed here)

    private var propertiesBinding: Binding<[Property.Resolved]> {
        Binding(
            get: { return component.displayedProperties },
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
            get: { self.component.referenceDesignatorIndex },
            set: { newIndex in
                projectManager.updateReferenceDesignator(for: self.component, newIndex: newIndex)
            }
        )
    }

    private var footprintBinding: Binding<UUID?> {
        Binding(
            get: { return component.footprintInstance?.definitionUUID },
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
                        value: refdesIndexBinding,
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
                        Text(selectedFootprintName)
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
