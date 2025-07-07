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

    @State private var selectedComponentInstances: Set<DesignComponent> = []
    
    var document: CircuitProjectDocument

    // 1. Delete logic, deferred to avoid exclusivity violations
    private func performDelete(on designComponent: DesignComponent) {
        // 1.1 Determine what to remove at the model level
        let instancesToRemove: [ComponentInstance]

        if selectedComponentInstances.contains(designComponent),
           selectedComponentInstances.count > 1 {
            instancesToRemove = selectedComponentInstances.map(\.instance)
            selectedComponentInstances.removeAll()
        } else {
            instancesToRemove = [designComponent.instance]
            selectedComponentInstances.remove(designComponent)
        }

        // 1.2 Remove from the selected design
        if (projectManager.selectedDesign?.componentInstances) != nil {
            projectManager.selectedDesign?.componentInstances.removeAll {
                inst in instancesToRemove.contains(where: { $0.id == inst.id })
            }
        }

        // 1.3 Persist change
        document.updateChangeCount(.changeDone)
    }

    var body: some View {

        List(projectManager.designComponents,
                 id: \.id,
                 selection: $selectedComponentInstances
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
                    // 3. Dynamic delete label/action
                    let multi = selectedComponentInstances.contains(designComponent) && selectedComponentInstances.count > 1
                    Button(role: .destructive) {
                        performDelete(on: designComponent)
                    } label: {
                        Text(multi
                             ? "Delete Selected (\(selectedComponentInstances.count))"
                             : "Delete")
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)

    }
}
