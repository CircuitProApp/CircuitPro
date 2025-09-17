//
//  SymbolNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.06.25.
//

import SwiftUI
// SwiftDataPacks is no longer needed here.

struct SymbolNavigatorView: View {
    
    @BindableEnvironment(\.projectManager)
    private var projectManager
    
    // The @PackManager is no longer needed.
    // @PackManager private var packManager
    
    var document: CircuitProjectFileDocument
    
    /// --- CORRECTED ---
    /// This function now works directly with ComponentInstance and is much simpler.
    private func performDelete(on componentInstance: ComponentInstance, selected: inout Set<UUID>) {
        let idsToRemove: Set<UUID>
        
        // Check if the component instance is part of a multi-selection.
        // It's important to check `selected.count > 1` here to differentiate
        // between a single-selection delete and a multi-selection delete that happens to include this item.
        let isMultiSelect = selected.contains(componentInstance.id) && selected.count > 1
        
        if isMultiSelect {
            // For multi-delete, we can just use the selection set directly.
            // No need to fetch or resolve anything.
            idsToRemove = selected
        } else {
            // For a single delete, it's just the ID of the passed-in instance.
            idsToRemove = [componentInstance.id]
        }
        
        // Remove the component instances from the project's source of truth.
        projectManager.selectedDesign?.componentInstances.removeAll { idsToRemove.contains($0.id) }
        
        // Clear the selection for the deleted items.
        // If it was a multi-select, clear all selected items.
        // If it was a single-select, remove only the deleted item from selection.
        selected.subtract(idsToRemove)
        
        // Persist the change to the document.
        document.scheduleAutosave()
    }
    
    var body: some View {
        
        // --- CORRECTED ---
        // We now use the hydrated componentInstances directly from the project manager.
        // I've renamed the variable for clarity.
        let componentInstances = projectManager.componentInstances
        
        VStack(spacing: 0) {
            if componentInstances.isEmpty {
                Spacer()
                Text("No Symbols")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(
                    componentInstances, // Use the direct list of instances
                    id: \.id,
                    selection: $projectManager.selectedNodeIDs
                ) { instance in // The loop variable is now a ComponentInstance
                    HStack {
                        // Safely access the name from the hydrated definition.
                        Text(instance.definition?.name ?? "Missing Definition")
                            .foregroundStyle(.primary)
                        Spacer()
                        // Use the helper property for the reference designator string.
                        Text((instance.definition?.referenceDesignatorPrefix ?? "?") + instance.referenceDesignatorIndex.description)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                    .frame(height: 14)
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        let multi = projectManager.selectedNodeIDs.contains(instance.id) && projectManager.selectedNodeIDs.count > 1
                        Button(role: .destructive) {
                            performDelete(on: instance, selected: &projectManager.selectedNodeIDs)
                        } label: {
                            Text(multi
                                 ? "Delete Selected (\(projectManager.selectedNodeIDs.count))"
                                 : "Delete")
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 14)
            }
        }
    }
}
