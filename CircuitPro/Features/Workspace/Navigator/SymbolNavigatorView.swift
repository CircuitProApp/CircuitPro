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

    @State private var selectedComponentIDs: Set<UUID> = []

    var document: CircuitProjectDocument

    // 1. Delete logic, deferred to avoid exclusivity violations
    private func performDelete(on designComponent: DesignComponent) {
        // 1.1 Determine what to remove at the model level
        let instancesToRemove: [ComponentInstance]

        let isMultiSelect = selectedComponentIDs.contains(designComponent.id) && selectedComponentIDs.count > 1

        if isMultiSelect {
            instancesToRemove = projectManager.designComponents
                .filter { selectedComponentIDs.contains($0.id) }
                .map(\.instance)
            selectedComponentIDs.removeAll()
        } else {
            instancesToRemove = [designComponent.instance]
            selectedComponentIDs.remove(designComponent.id)
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
        List(
            projectManager.designComponents,
            id: \.id,
            selection: $selectedComponentIDs
        ) { designComponent in
            HStack {
                Text(designComponent.definition.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text(designComponent.reference)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            .frame(height: 14)
            .listRowSeparator(.hidden)
            .contextMenu {
                let multi = selectedComponentIDs.contains(designComponent.id) && selectedComponentIDs.count > 1
                Button(role: .destructive) {
                    performDelete(on: designComponent)
                } label: {
                    Text(multi
                         ? "Delete Selected (\(selectedComponentIDs.count))"
                         : "Delete")
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 14)
    }
}
