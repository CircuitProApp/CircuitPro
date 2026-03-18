//
//  SymbolNavigatorView.swift
//  CircuitPro
//

import SwiftUI

struct SymbolNavigatorView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager

    @BindableEnvironment(\.editorSession)
    private var editorSession

    // Stamp changes when pending records are added/updated/removed
    private var pendingStamp: Int {
        projectManager.syncManager.pendingChanges.map(\.id).hashValue
    }

    private func performDelete(on componentInstance: ComponentInstance, selected: inout Set<UUID>) {
        let idsToRemove: Set<UUID>
        let isMultiSelect = selected.contains(componentInstance.id) && selected.count > 1
        idsToRemove = isMultiSelect ? selected : [componentInstance.id]
        projectManager.selectedDesign.componentInstances.removeAll { idsToRemove.contains($0.id) }
        selected.subtract(idsToRemove)
        projectManager.document.scheduleAutosave()
    }

    var body: some View {
        let componentInstances = projectManager.componentInstances

        SidebarListView(
            items: componentInstances,
            id: \.id,
            selection: $editorSession.selectedItemIDs
        ) { instance in
            HStack {
                Text(instance.definition?.name ?? "Missing Definition")
                    .foregroundStyle(.primary)
                Spacer()
                // Show schematic-resolved RefDes (pending schematic edits become “truth” here)
                let prefix = instance.definition?.referenceDesignatorPrefix ?? "?"
                let idx = projectManager.syncManager.resolvedReferenceDesignator(
                    for: instance, onlyFrom: .schematic)
                Text(prefix + String(idx))
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .contextMenu {
                let multi =
                    editorSession.selectedItemIDs.contains(instance.id)
                    && editorSession.selectedItemIDs.count > 1
                Button(role: .destructive) {
                    performDelete(on: instance, selected: &editorSession.selectedItemIDs)
                } label: {
                    Text(
                        multi
                            ? "Delete Selected (\(editorSession.selectedItemIDs.count))"
                            : "Delete")
                }
            }
        } emptyContent: {
            SidebarContentUnavailableView("No Symbols")
        }
        .id(pendingStamp)  // refresh when pending changes are updated
    }
}
