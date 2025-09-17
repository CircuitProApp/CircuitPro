//
//  TimelineView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import SwiftUI
import SwiftData

// A helper struct to represent a group of changes for the List.
// It's Identifiable by the component's UUID.
struct TimelineGroup: Identifiable {
    let id: UUID // This is the componentID
    let changes: [ChangeRecord]
    
    // A computed property to get all change IDs in this group easily.
    var allChangeIDsInGroup: Set<UUID> {
        Set(changes.map { $0.id })
    }
}

struct TimelineView: View {
    @Environment(\.projectManager) private var projectManager
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allFootprints: [FootprintDefinition]
    
    // State to hold the set of selected ChangeRecord IDs.
    @State private var selection: Set<ChangeRecord.ID> = []
    // --- ADDED: State to track the expansion of each group ---
    @State private var expandedGroups: [UUID: Bool] = [:]
    
    // We compute an array of TimelineGroup structs to drive the UI.
    private var timelineGroups: [TimelineGroup] {
        let groupedDictionary = Dictionary(grouping: projectManager.syncManager.pendingChanges) { record in
            // Group by the componentID from the payload.
            switch record.payload {
            case .updateReferenceDesignator(let id, _, _),
                 .assignFootprint(let id, _, _, _),
                 .updateProperty(let id, _, _):
                return id
            }
        }
        
        // Map the dictionary to an array of our TimelineGroup structs and sort them.
        return groupedDictionary.map { (componentID, changes) in
            TimelineGroup(id: componentID, changes: changes)
        }.sorted { componentName(for: $0.id) < componentName(for: $1.id) }
    }
    
    /// A helper to get the human-readable name for a component, including its pending state.
    private func componentName(for id: UUID) -> String {
        if let component = projectManager.componentInstances.first(where: { $0.id == id }) {
            let prefix = component.definition?.referenceDesignatorPrefix ?? "COMP"
            let index = projectManager.resolvedReferenceDesignator(for: component)
            
            if index != component.referenceDesignatorIndex {
                return "\(prefix)\(index) (Pending)"
            }
            return "\(prefix)\(index)"
        }
        return "Unknown Component"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            if timelineGroups.isEmpty {
                ContentUnavailableView("No Pending Changes", systemImage: "checklist")
            } else {
                List {
                    ForEach(timelineGroups) { group in
                        // --- MODIFIED: Use the DisclosureGroup initializer that takes a binding ---
                        DisclosureGroup(isExpanded: bindingForGroup(id: group.id)) {
                            ForEach(group.changes) { record in
                                ChangeRecordRowView(record: record, selection: $selection)
                            }
                        } label: {
                            GroupSelectionRow(
                                title: componentName(for: group.id),
                                changeCount: group.changes.count,
                                allChangeIDsInGroup: group.allChangeIDsInGroup,
                                selection: $selection
                            )
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            
            Divider()
            footer
        }
        .frame(minWidth: 600, minHeight: 500, idealHeight: 700)
        // --- ADDED: onAppear modifier to set the default expansion state ---
        .onAppear {
            // When the view first appears, iterate through all groups and set them to be expanded.
            for group in timelineGroups {
                expandedGroups[group.id] = true
            }
        }
    }
    
    /// A helper function to create a Binding to our state dictionary for each group.
    private func bindingForGroup(id: UUID) -> Binding<Bool> {
        return Binding(
            get: {
                // If a value exists in the dictionary, use it. Otherwise, default to false (collapsed).
                expandedGroups[id, default: false]
            },
            set: { newValue in
                // When the user clicks the disclosure triangle, update the state in our dictionary.
                expandedGroups[id] = newValue
            }
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
                    projectManager.applyChanges(
                        projectManager.syncManager.pendingChanges,
                        allFootprints: allFootprints
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
            } else {
                Button("Discard \(selection.count) Selected ", role: .destructive) {
                    projectManager.discardChanges(withIDs: selection)
                    selection.removeAll()
                }
                
                Button("Apply \(selection.count) Selected") {
                    projectManager.applyChanges(withIDs: selection, allFootprints: allFootprints)
                    selection.removeAll()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .buttonBorderShape(.capsule)
        .disabled(projectManager.syncManager.pendingChanges.isEmpty)
    }
}

// MARK: - Subviews for the List (Unchanged)

private struct GroupSelectionRow: View {
    let title: String
    let changeCount: Int
    let allChangeIDsInGroup: Set<UUID>
    @Binding var selection: Set<UUID>
    
    private var isSelected: Binding<Bool> {
        Binding(
            get: { allChangeIDsInGroup.isSubset(of: selection) },
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

private struct ChangeRecordRowView: View {
    let record: ChangeRecord
    @Binding var selection: Set<UUID>

    var body: some View {
        HStack(alignment: .top) {
            Toggle(isOn: Binding(
                get: { selection.contains(record.id) },
                set: { isSelected in
                    if isSelected {
                        selection.insert(record.id)
                    } else {
                        selection.remove(record.id)
                    }
                }
            )) {}
                .toggleStyle(.checkbox)
                .padding(.trailing, 4)

            VStack(alignment: .leading, spacing: 8) {
                switch record.payload {
                case .updateReferenceDesignator(_, let newIndex, let oldIndex):
                    ComparisonView(label: "RefDes Index", oldValue: "\(oldIndex)", newValue: "\(newIndex)")
                case .assignFootprint(_, _, let newName, let oldName):
                    ComparisonView(label: "Footprint", oldValue: oldName ?? "None", newValue: newName ?? "None")
                case .updateProperty(_, let newProperty, let oldProperty):
                    ComparisonView(label: newProperty.key.label, oldValue: oldProperty.value.description, newValue: newProperty.value.description)
                }
            }
        }
        .padding(.vertical, 6)
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
