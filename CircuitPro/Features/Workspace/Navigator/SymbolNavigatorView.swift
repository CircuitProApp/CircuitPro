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
    @Query private var symbols: [Symbol]          // All symbols
    @State  private var selectedComponentInstance: ComponentInstance?

    // Helper: UUID → Symbol name
    private func name(for uuid: UUID) -> String {
        symbols.first(where: { $0.uuid == uuid })?.name ?? "⚠︎ missing"
    }

    var body: some View {
        @Bindable var manager = projectManager

        if let design = Binding($manager.selectedDesign) {
            // optional: build a dictionary once per render for O(1) look-ups
            let symbolNames = Dictionary(uniqueKeysWithValues:
                                         symbols.map { ($0.uuid, $0.name) })

            List(design.componentInstances,
                 id: \.self,
                 selection: $selectedComponentInstance) { $instance in

                HStack {
                    Text(symbolNames[instance.symbolInstance.symbolUUID] ?? "⚠︎ missing")
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .frame(height: 14)
                .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)
        } else {
            Color.clear.frame(maxHeight: .infinity)
        }
    }
}
