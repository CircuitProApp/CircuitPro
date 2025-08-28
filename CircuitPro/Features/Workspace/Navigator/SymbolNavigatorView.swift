//
//  SymbolNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.06.25.
//

import SwiftUI
import SwiftDataPacks // Import this to use @PackManager

struct SymbolNavigatorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    // 1. Get the PackManager from the environment.
    @PackManager private var packManager
    
    // This @Query is likely no longer needed as component definitions are
    // fetched through the projectManager and packManager.
    // @Query private var components: [Component]
    
    var document: CircuitProjectFileDocument
    
    // 3. Update the delete logic. It can now access `packManager` from the view's properties.
    private func performDelete(on designComponent: DesignComponent, selected: inout Set<UUID>) {
        let idsToRemove: Set<UUID>
        
        let isMultiSelect = selected.contains(designComponent.id) && selected.count > 1
        
        if isMultiSelect {
            // To handle multi-delete, we need to resolve all design components
            // using the packManager, filter by the selection, and get their instance IDs.
            let allDesignComponents = projectManager.designComponents(using: packManager)
            idsToRemove = Set(allDesignComponents.filter { selected.contains($0.id) }.map(\.instance.id))
            selected.removeAll()
        } else {
            // For a single delete, we just need the instance ID of the target component.
            idsToRemove = [designComponent.instance.id]
            selected.remove(designComponent.id)
        }
        
        // Remove the component instances from the project's source of truth.
        // This change will be automatically detected by SchematicCanvasView's .onChange,
        // which will then trigger a canvas rebuild.
        projectManager.selectedDesign?.componentInstances.removeAll { idsToRemove.contains($0.id) }
        
        // Persist the change to the document.
        document.scheduleAutosave()
    }
    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        
        // 2. Fetch the design components here, inside the body.
        // The view will automatically re-render when the underlying data changes.
        let designComponents = projectManager.designComponents(using: packManager)
        VStack(spacing: 0) {
            if designComponents.isEmpty {
                Spacer()
                Text("No Symbols")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(
                    designComponents, // Use the locally fetched components
                    id: \.id,
                    selection: $bindableProjectManager.selectedNodeIDs
                ) { designComponent in
                    HStack {
                        Text(designComponent.definition.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(designComponent.referenceDesignator)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                    .frame(height: 14)
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        let multi = bindableProjectManager.selectedNodeIDs.contains(designComponent.id) && bindableProjectManager.selectedNodeIDs.count > 1
                        Button(role: .destructive) {
                            performDelete(on: designComponent, selected: &bindableProjectManager.selectedNodeIDs)
                        } label: {
                            Text(multi
                                 ? "Delete Selected (\(bindableProjectManager.selectedNodeIDs.count))"
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
