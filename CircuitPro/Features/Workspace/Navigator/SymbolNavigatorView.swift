//
//  SymbolNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.06.25.
//

import SwiftUI
import SwiftData

struct SymbolNavigatorView: View {
    @Environment(\.projectManager) private var projectManager
    @Query private var components: [Component]
    @State private var selectedComponentInstances: Set<ComponentInstance> = []
    
    var document: CircuitProjectDocument

    // 1. Delete logic, deferred to avoid exclusivity violations
    private func performDelete(on instance: ComponentInstance) {
        let selection = selectedComponentInstances
        DispatchQueue.main.async {
            if selection.contains(instance) && selection.count > 1 {
                projectManager.selectedDesign?.componentInstances.removeAll { selection.contains($0) }
                selectedComponentInstances.removeAll()
            } else {
                projectManager.selectedDesign?.componentInstances.removeAll { $0 == instance }
                selectedComponentInstances.remove(instance)
            }
            document.updateChangeCount(.changeDone)
        }
    }

    var body: some View {
        @Bindable var manager = projectManager

        if let design = Binding($manager.selectedDesign) {
            // 2. Build name lookup once per render
            let names = Dictionary(uniqueKeysWithValues:
                components.map { ($0.symbol?.uuid, $0.symbol?.name) }
            )

            List(design.componentInstances,
                 id: \.self,
                 selection: $selectedComponentInstances
            ) { $instance in
                HStack {
                    Text((names[instance.symbolInstance.symbolUUID] ?? "⚠︎ missing") ?? "No Component")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text((components.first(where: { $0.uuid == instance.componentUUID })?.abbreviation ?? "No Name")
                         + instance.reference.description)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                .frame(height: 14)
                .listRowSeparator(.hidden)
                .contextMenu {
                    // 3. Dynamic delete label/action
                    let multi = selectedComponentInstances.contains(instance) && selectedComponentInstances.count > 1
                    Button(role: .destructive) {
                        performDelete(on: instance)
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
        } else {
            Color.clear.frame(maxHeight: .infinity)
        }
    }
}
