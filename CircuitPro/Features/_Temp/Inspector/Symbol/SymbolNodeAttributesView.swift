//
//  SymbolNodeAttributesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/19/25.
//


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
    
    @State private var commitSessionID: UUID? // NEW

    private func withCommitSession(_ perform: (UUID) -> Void) {
        let id: UUID
        if let s = commitSessionID {
            id = s
        } else {
            id = projectManager.syncManager.beginSession()
            commitSessionID = id
            // End the session after the current commit burst settles.
            DispatchQueue.main.async { [weak projectManager] in
                projectManager?.syncManager.endSession(id)
                commitSessionID = nil
            }
        }
        perform(id)
    }

    // MARK: - Bindings

    // Refdes
    private var refdesIndexBinding: Binding<Int> {
        Binding(
            get: { projectManager.resolvedReferenceDesignator(for: self.component) },
            set: { newIndex in
                let current = projectManager.resolvedReferenceDesignator(for: self.component)
                guard newIndex != current else { return }
                withCommitSession { session in
                    projectManager.updateReferenceDesignator(for: self.component, newIndex: newIndex, sessionID: session)
                }
            }
        )
    }

    // Footprint
    private var footprintBinding: Binding<UUID?> {
        Binding(
            get: { projectManager.resolvedFootprintUUID(for: component) },
            set: { newUUID in
                let current = projectManager.resolvedFootprintUUID(for: component)
                guard newUUID != current else { return }
                withCommitSession { session in
                    if let id = newUUID, let fp = allFootprints.first(where: { $0.uuid == id }) {
                        projectManager.assignFootprint(to: component, footprint: fp, sessionID: session)
                    } else {
                        projectManager.assignFootprint(to: component, footprint: nil, sessionID: session)
                    }
                }
            }
        )
    }

    // Properties table (array -> per-row diff vs resolved)
    private var propertiesBinding: Binding<[Property.Resolved]> {
        Binding(
            get: {
                component.displayedProperties.compactMap { original in
                    projectManager.resolvedProperty(for: component, propertyID: original.id)
                }
            },
            set: { newArray in
                // Build resolved-current map once
                let currentByID: [UUID: Property.Resolved] = Dictionary(
                    uniqueKeysWithValues: component.displayedProperties.compactMap { original in
                        guard let resolved = projectManager.resolvedProperty(for: component, propertyID: original.id) else { return nil }
                        return (original.id, resolved)
                    }
                )
                var didChange = false
                withCommitSession { session in
                    for newProp in newArray {
                        guard let cur = currentByID[newProp.id] else { continue }
                        if newProp.value != cur.value || newProp.unit != cur.unit {
                            didChange = true
                            projectManager.updateProperty(for: component, with: newProp, sessionID: session)
                        }
                    }
                }
                _ = didChange // keep for breakpoints if you like
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