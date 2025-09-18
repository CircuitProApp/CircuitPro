// Features/_Temp/Inspector/ComponentAttributesView.swift
//
//  ComponentAttributesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 09.18.25.
//  Unified attributes view for SymbolNode and FootprintNode.
//

import SwiftUI
import SwiftData

struct ComponentAttributesView: View {
    @Environment(\.projectManager) private var projectManager
    
    @Bindable var component: ComponentInstance
    @Bindable var node: BaseNode // Can be SymbolNode or FootprintNode
    
    @Query(sort: \FootprintDefinition.name) private var allFootprints: [FootprintDefinition]
    
    @State private var selectedProperty: Property.Resolved.ID?
    @State private var commitSessionID: UUID?

    private func withCommitSession(_ perform: (UUID) -> Void) {
        let id: UUID
        if let s = commitSessionID {
            id = s
        } else {
            id = projectManager.syncManager.beginSession()
            commitSessionID = id
            DispatchQueue.main.async { [weak projectManager] in
                projectManager?.syncManager.endSession(id)
                commitSessionID = nil
            }
        }
        perform(id)
    }

    // MARK: - Bindings (Generalized)

    private var refdesIndexBinding: Binding<Int> {
        Binding(
            get: {
                if node is FootprintNode {
                    return projectManager.resolvedReferenceDesignator(for: self.component, onlyFrom: .layout)
                } else { // Assume SymbolNode if not FootprintNode
                    return projectManager.resolvedReferenceDesignator(for: self.component)
                }
            },
            set: { newIndex in
                let current: Int
                if node is FootprintNode {
                    current = projectManager.resolvedReferenceDesignator(for: self.component, onlyFrom: .layout)
                } else {
                    current = projectManager.resolvedReferenceDesignator(for: self.component)
                }
                
                guard newIndex != current else { return }
                withCommitSession { session in
                    projectManager.updateReferenceDesignator(for: self.component, newIndex: newIndex, sessionID: session)
                }
            }
        )
    }

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

    private var propertiesBinding: Binding<[Property.Resolved]> {
        Binding(
            get: {
                component.displayedProperties.compactMap { original in
                    projectManager.resolvedProperty(for: component, propertyID: original.id)
                }
            },
            set: { newArray in
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
                _ = didChange
            }
        )
    }
    
    private var compatibleFootprints: [FootprintDefinition] {
        component.definition?.footprints.sorted(by: { $0.name < $1.name }) ?? []
    }
    private var otherFootprints: [FootprintDefinition] {
        let compatibleUUIDs = Set(compatibleFootprints.map { $0.uuid })
        return allFootprints.filter { !compatibleUUIDs.contains($0.uuid) }
    }
    private var selectedFootprintName: String {
        return projectManager.resolvedFootprintName(for: component) ?? "None"
    }

    private var rotatableObjectBinding: Binding<some RotatableObject> {
        Binding(
            get: {
                if let symbolNode = node as? SymbolNode {
                    return symbolNode.instance // SymbolInstance conforms to RotatableObject
                } else if let footprintNode = node as? FootprintNode {
                    return footprintNode.instance // FootprintInstance conforms to RotatableObject
                } else {
                    fatalError("Node type not supported for RotationControlView")
                }
            },
            set: { newRotatable in
                if let symbolNode = node as? SymbolNode {
                    symbolNode.instance.rotation = newRotatable.rotation
                } else if let footprintNode = node as? FootprintNode {
                    footprintNode.instance.rotation = newRotatable.rotation
                }
                node.onNeedsRedraw?() // Trigger redraw after change
            }
        )
    }

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

            if let symbolNode = node as? SymbolNode {
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
            }
            
            if let footprintNode = node as? FootprintNode {
                InspectorSection("Placement") {
                    InspectorRow("Side") {
                        Picker("Side", selection: Binding(
                            get: {
                                if case .placed(let side) = footprintNode.instance.placement { return side }
                                return .front
                            },
                            set: { newSide in
                                footprintNode.instance.placement = .placed(side: newSide)
                            }
                        )) {
                            Text("Front").tag(BoardSide.front)
                            Text("Back").tag(BoardSide.back)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }
                Divider()
            }

            InspectorSection("Transform") {
                PointControlView(
                    title: "Position",
                    point: $node.position
                )
                RotationControlView(object: rotatableObjectBinding)
            }
            Divider()
            
            if node is SymbolNode {
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
        }
        .onChange(of: component) {
            node.onNeedsRedraw?()
        }
    }
}