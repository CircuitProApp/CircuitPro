//
//  SymbolNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.06.25.
//

import SwiftUI
import SwiftData

struct SymbolNavigatorView: View {

    @Environment(\.projectManager)
    private var projectManager

    @Query private var components: [Component]


    var document: CircuitProjectDocument

    // 1. Delete logic, deferred to avoid exclusivity violations
    private func performDelete(on designComponent: DesignComponent, selected: inout Set<UUID>) {
        // 1.1 Determine what to remove at the model level
        let instancesToRemove: [ComponentInstance]

        let isMultiSelect = selected.contains(designComponent.id) && selected.count > 1

        if isMultiSelect {
            instancesToRemove = projectManager.designComponents
                .filter { selected.contains($0.id) }
                .map(\.instance)
            selected.removeAll()
        } else {
            instancesToRemove = [designComponent.instance]
            selected.remove(designComponent.id)
        }

        // 1.2 Remove from the selected design
        if let _ = projectManager.selectedDesign?.componentInstances {
            projectManager.selectedDesign?.componentInstances.removeAll { inst in
                instancesToRemove.contains(where: { $0.id == inst.id })
            }
        }

        // 1.3 Persist change
        document.updateChangeCount(.changeDone)
    }

    var body: some View {
        @Bindable var bindableProjectManager = projectManager

        if projectManager.designComponents.isEmpty {
            VStack {
                Text("No Symbols")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(
                projectManager.designComponents,
                id: \.id,
                selection: $bindableProjectManager.selectedComponentIDs
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
                    let multi = bindableProjectManager.selectedComponentIDs.contains(designComponent.id) && bindableProjectManager.selectedComponentIDs.count > 1
                    Button(role: .destructive) {
                        performDelete(on: designComponent, selected: &bindableProjectManager.selectedComponentIDs)
                    } label: {
                        Text(multi
                             ? "Delete Selected (\(bindableProjectManager.selectedComponentIDs.count))"
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
