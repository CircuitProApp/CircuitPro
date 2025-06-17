//
//  SymbolNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.06.25.
//

import SwiftUI

struct SymbolNavigatorView: View {

    @Environment(\.projectManager)
    private var projectManager

    @State private var selectedComponentInstance: ComponentInstance?

    var body: some View {
        @Bindable var manager = projectManager

        if let design = Binding($manager.selectedDesign) {
            List(
                design.componentInstances,
                id: \.self,
                selection: $selectedComponentInstance
            ) { $instance in
                
                HStack {
                    Text(instance.symbolInstance.symbolUUID.description)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 14)
                .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)
        } else {
            Color.clear
                .frame(maxHeight: .infinity)
        }
    }
}
