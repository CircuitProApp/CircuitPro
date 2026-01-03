//
//  FootprintNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import SwiftUI

struct FootprintNavigatorView: View {
    @BindableEnvironment(\.projectManager) private var projectManager
    @BindableEnvironment(\.editorSession) private var editorSession

    private var unplacedComponents: [ComponentInstance] {
        projectManager.componentInstances.filter {
            $0.footprintInstance?.placement == .unplaced
        }
    }

    private func placedComponents(on side: BoardSide) -> [ComponentInstance] {
        projectManager.componentInstances.filter { component in
            guard let footprint = component.footprintInstance else { return false }
            if case .placed(let footprintSide) = footprint.placement {
                return footprintSide == side
            }
            return false
        }
    }

    /// Handles deletion of component instances based on selection.
    // This function is identical to the one in SymbolNavigatorView.
    private func performDelete(on componentInstance: ComponentInstance, selected: inout Set<UUID>) {
        let idsToRemove: Set<UUID>

        let isMultiSelect = selected.contains(componentInstance.id) && selected.count > 1

        if isMultiSelect {
            idsToRemove = selected
        } else {
            idsToRemove = [componentInstance.id]
        }

        projectManager.selectedDesign.componentInstances.removeAll { idsToRemove.contains($0.id) }
        selected.subtract(idsToRemove) // Clear selection for deleted items
        projectManager.document.scheduleAutosave()
    }

    var body: some View {
        VStack(spacing: 0) { // Added VStack for similar structure to SymbolNavigatorView
            if projectManager.componentInstances.isEmpty { // Checking all component instances
                Spacer()
                Text("No Footprints") // Adjusted text
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(selection: $editorSession.selectedItemIDs) { // Apply selection to the entire List
                    Section("Unplaced") {
                        if unplacedComponents.isEmpty {
                            Text("All components placed.")
                                .foregroundStyle(.secondary)
                        } else {
                            // Make sure ForEach iterates over the ComponentInstance itself
                            ForEach(unplacedComponents) { component in
                                componentRow(for: component)
                                    .listRowSeparator(.hidden) // Added row separator style
                                    // --- ADDED: Make this row draggable ---
                                    .draggable(TransferablePlacement(componentInstanceID: component.id))
                                    // Add context menu for deletion
                                    .contextMenu {
                                        let multi = editorSession.selectedItemIDs.contains(component.id) && editorSession.selectedItemIDs.count > 1
                                        Button(role: .destructive) {
                                            performDelete(on: component, selected: &editorSession.selectedItemIDs)
                                        } label: {
                                            Text(multi
                                                 ? "Delete Selected (\(editorSession.selectedItemIDs.count))"
                                                 : "Delete")
                                        }
                                    }
                            }
                        }
                    }

                    Section("Placed on Front") {
                        let frontComponents = placedComponents(on: .front)
                        if frontComponents.isEmpty {
                            Text("No components on front.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(frontComponents) { component in
                                componentRow(for: component)
                                    .listRowSeparator(.hidden) // Added row separator style
                                    // Add context menu for deletion
                                    .contextMenu {
                                        let multi = editorSession.selectedItemIDs.contains(component.id) && editorSession.selectedItemIDs.count > 1
                                        Button(role: .destructive) {
                                            performDelete(on: component, selected: &editorSession.selectedItemIDs)
                                        } label: {
                                            Text(multi
                                                 ? "Delete Selected (\(editorSession.selectedItemIDs.count))"
                                                 : "Delete")
                                        }
                                    }
                            }
                        }
                    }

                    Section("Placed on Back") {
                        let backComponents = placedComponents(on: .back)
                        if backComponents.isEmpty {
                            Text("No components on back.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(backComponents) { component in
                                componentRow(for: component)
                                    .listRowSeparator(.hidden) // Added row separator style
                                    // Add context menu for deletion
                                    .contextMenu {
                                        let multi = editorSession.selectedItemIDs.contains(component.id) && editorSession.selectedItemIDs.count > 1
                                        Button(role: .destructive) {
                                            performDelete(on: component, selected: &editorSession.selectedItemIDs)
                                        } label: {
                                            Text(multi
                                                 ? "Delete Selected (\(editorSession.selectedItemIDs.count))"
                                                 : "Delete")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.inset) // Applied .inset list style
                .scrollContentBackground(.hidden) // Applied .hidden scroll content background
                .environment(\.defaultMinListRowHeight, 14) // Applied defaultMinListRowHeight
            }
        }
    }

    @ViewBuilder
    private func componentRow(for component: ComponentInstance) -> some View {
        HStack {
            Text(component.referenceDesignator)
            Spacer()
            Text(component.footprintInstance?.definition?.name ?? "Default")
                .foregroundStyle(.secondary)
        }
        .frame(height: 14) // Applied frame height for the row
    }
}
