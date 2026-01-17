//
//  TimelineView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import SwiftUI
import SwiftData

// Field key within a component: one entry per edited field, with history
private enum FieldKey: Hashable {
    case refdes
    case footprint
    case property(UUID) // propertyID
}

// Top-level group: per-component
private struct TimelineComponentGroup: Identifiable {
    let id: UUID // componentID
    let fields: [TimelineFieldGroup]
}

// One row in a component group: one field, with its history (newest-first)
private struct TimelineFieldGroup: Identifiable {
    let id: String                 // componentID + fieldKey composite
    let fieldKey: FieldKey
    let history: [ChangeRecord]    // newest-first

    var latest: ChangeRecord { history.first! }
    var stageCount: Int { history.count }
    var allChangeIDsInField: Set<UUID> { Set(history.map(\.id)) }
}

struct TimelineView: View {
    @Environment(\.projectManager) private var projectManager
    @Environment(\.dismiss) private var dismiss

    @Query private var allFootprints: [FootprintDefinition]

    // Selection holds ChangeRecord IDs. Field toggles add/remove all IDs in that field.
    @State private var selection: Set<ChangeRecord.ID> = []
    @State private var expandedComponents: [UUID: Bool] = [:]

    // Build groups: Component -> Field -> History
    private var timelineGroups: [TimelineComponentGroup] {
        let records = projectManager.syncManager.pendingChanges

        // Group by component
        let byComponent = Dictionary(grouping: records) { (rec: ChangeRecord) -> UUID in
            switch rec.payload {
            case .updateReferenceDesignator(let id, _, _),
                 .assignFootprint(let id, _, _, _),
                 .updateProperty(let id, _, _):
                return id
            }
        }

        // Map to component groups
        let componentGroups: [TimelineComponentGroup] = byComponent.map { (componentID, componentRecords) in
            // For each component, group by field key
            let byField: [FieldKey: [ChangeRecord]] = Dictionary(grouping: componentRecords) { rec in
                switch rec.payload {
                case .updateReferenceDesignator:
                    return .refdes
                case .assignFootprint:
                    return .footprint
                case .updateProperty(_, let newProp, _):
                    return .property(newProp.id)
                }
            }

            // Build TimelineFieldGroup per field, newest-first history
            let fieldGroups: [TimelineFieldGroup] = byField.map { (key, recs) in
                let sorted = recs.sorted(by: { $0.timestamp > $1.timestamp })
                return TimelineFieldGroup(
                    id: fieldGroupID(componentID: componentID, key: key),
                    fieldKey: key,
                    history: sorted
                )
            }
            // Sort fields by human-readable label
            .sorted { fieldLabel(for: $0) < fieldLabel(for: $1) }

            return TimelineComponentGroup(id: componentID, fields: fieldGroups)
        }
        // Sort components by their display name
        .sorted { componentName(for: $0.id) < componentName(for: $1.id) }

        return componentGroups
    }

    private func fieldGroupID(componentID: UUID, key: FieldKey) -> String {
        switch key {
        case .refdes:
            return "refdes:\(componentID.uuidString)"
        case .footprint:
            return "footprint:\(componentID.uuidString)"
        case .property(let pid):
            return "prop:\(componentID.uuidString):\(pid.uuidString)"
        }
    }

    /// A helper to get the human-readable name for a component, including its pending state.
    private func componentName(for id: UUID) -> String {
        if let component = projectManager.componentInstances.first(where: { $0.id == id }) {
            let prefix = component.definition?.referenceDesignatorPrefix ?? "COMP"
            let index = projectManager.syncManager.resolvedReferenceDesignator(for: component)
            if index != component.referenceDesignatorIndex {
                return "\(prefix)\(index) (Pending)"
            }
            return "\(prefix)\(index)"
        }
        return "Unknown Component"
    }

    /// Human-readable field label from the latest record of a field group.
    private func fieldLabel(for group: TimelineFieldGroup) -> String {
        switch group.latest.payload {
        case .updateReferenceDesignator:
            return "Reference Designator"
        case .assignFootprint:
            return "Footprint"
        case .updateProperty(_, let newProperty, _):
            return newProperty.key.label
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            // Always show a List (even when empty) – no ContentUnavailableView
            List {
                ForEach(timelineGroups) { comp in
                    DisclosureGroup(isExpanded: bindingForComponent(id: comp.id)) {
                        ForEach(comp.fields) { field in
                            FieldGroupRow(
                                componentID: comp.id,
                                field: field,
                                fieldLabel: fieldLabel(for: field),
                                selection: $selection
                            )
                        }
                    } label: {
                        GroupSelectionRow(
                            title: componentName(for: comp.id),
                            // Count fields, not records
                            changeCount: comp.fields.count,
                            // Component-level "select all fields"
                            allChangeIDsInGroup: Set(comp.fields.flatMap { $0.allChangeIDsInField }),
                            selection: $selection
                        )
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
            footer
        }
        .frame(minWidth: 600, minHeight: 500, idealHeight: 700)
        .onAppear {
            // Expand all components on first show
            for comp in timelineGroups {
                expandedComponents[comp.id] = true
            }
        }
    }

    private func bindingForComponent(id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedComponents[id, default: false] },
            set: { expandedComponents[id] = $0 }
        )
    }

    private var header: some View {
        HStack {
            Text("Pending Changes")
                .font(.title2).bold()
                .padding()
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel", role: .cancel) { dismiss() }

            Spacer()

            if selection.isEmpty {
                Button("Discard All", role: .destructive) {
                    projectManager.discardPendingChanges()
                    dismiss()
                }
                .tint(.red)

                Button("Apply All") {
                    let records = projectManager.syncManager.pendingChanges
                    projectManager.applyChanges(records, allFootprints: allFootprints)
                    projectManager.discardPendingChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

            } else {
                Button("Discard \(selection.count) Selected", role: .destructive) {
                    projectManager.discardChanges(withIDs: selection)
                    selection.removeAll()
                }

                Button("Apply \(selection.count) Selected") {
                    projectManager.applyChanges(withIDs: selection, allFootprints: allFootprints)
                    selection.removeAll()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .buttonBorderShape(.capsule)
        .disabled(projectManager.syncManager.pendingChanges.isEmpty)
    }
}

// MARK: - Subviews

// Component-level selection header row
private struct GroupSelectionRow: View {
    let title: String
    let changeCount: Int                 // number of fields edited in this component
    let allChangeIDsInGroup: Set<UUID>   // all record IDs belonging to all fields in this component
    @Binding var selection: Set<UUID>

    private var isSelected: Binding<Bool> {
        Binding(
            get: { allChangeIDsInGroup.isSubset(of: selection) && !allChangeIDsInGroup.isEmpty },
            set: { shouldBeSelected in
                if shouldBeSelected {
                    selection.formUnion(allChangeIDsInGroup)
                } else {
                    selection.subtract(allChangeIDsInGroup)
                }
            }
        )
    }

    var body: some View {
        HStack {
            Toggle(isOn: isSelected) {}
                .toggleStyle(.checkbox)
                .padding(.trailing, 4)

            Text(title)
                .font(.headline)
            Text("(\(changeCount) Changes)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// Field-level row: shows latest change and how many stages (history length).
private struct FieldGroupRow: View {
    let componentID: UUID
    let field: TimelineFieldGroup
    let fieldLabel: String
    @Binding var selection: Set<UUID>

    private var isSelected: Binding<Bool> {
        Binding(
            get: { field.allChangeIDsInField.isSubset(of: selection) && !field.allChangeIDsInField.isEmpty },
            set: { shouldBeSelected in
                if shouldBeSelected {
                    selection.formUnion(field.allChangeIDsInField)
                } else {
                    selection.subtract(field.allChangeIDsInField)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Toggle(isOn: isSelected) {}
                    .toggleStyle(.checkbox)
                    .padding(.trailing, 4)

                // Render the latest change for this field
                VStack(alignment: .leading, spacing: 4) {
                    switch field.latest.payload {
                    case .updateReferenceDesignator(_, let newIndex, let oldIndex):
                        ComparisonView(label: fieldLabel, oldValue: "\(oldIndex)", newValue: "\(newIndex)")
                    case .assignFootprint(_, _, let newName, let oldName):
                        ComparisonView(label: fieldLabel, oldValue: oldName ?? "None", newValue: newName ?? "None")
                    case .updateProperty(_, let newProperty, let oldProperty):
                        ComparisonView(label: fieldLabel, oldValue: oldProperty.value.description, newValue: newProperty.value.description)
                    }

                    // Stages indicator
                    if field.stageCount > 1 {
                        Text("\(field.stageCount) stages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Optional: show per-stage history collapsed; uncomment to visualize every stage.
            /*
            VStack(alignment: .leading, spacing: 2) {
                ForEach(field.history) { rec in
                    StageRow(record: rec)
                }
            }
            .padding(.leading, 24)
            */
        }
        .padding(.vertical, 6)
    }
}

// Optional per-stage row (if you want to show the entire history inside a field row)
private struct StageRow: View {
    let record: ChangeRecord
    var body: some View {
        switch record.payload {
        case .updateReferenceDesignator(_, let newIndex, let oldIndex):
            Text("• \(oldIndex) → \(newIndex)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .assignFootprint(_, _, let newName, let oldName):
            Text("• \(oldName ?? "None") → \(newName ?? "None")")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .updateProperty(_, let newProperty, let oldProperty):
            Text("• \(oldProperty.value.description) → \(newProperty.value.description)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ComparisonView: View {
    let label: String
    let oldValue: String
    let newValue: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                Text(oldValue)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Text(newValue)
                    .fontWeight(.semibold)
                Spacer()
            }
        } label: {
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
