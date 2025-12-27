//
//  SymbolNodeInspectorHostView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftUI
import SwiftDataPacks

struct SymbolNodeInspectorHostView: View {

    var component: ComponentInstance
    @Binding var symbol: GraphSymbolComponent

    @Binding var selectedTab: InspectorTab

    private let availableTabs: [InspectorTab] = [.attributes, .appearance]

    var body: some View {
        SidebarView(selectedTab: $selectedTab, availableTabs: availableTabs) {
            ScrollView {
                switch selectedTab {
                case .attributes:
                    SymbolNodeAttributesView(component: component, symbol: $symbol)
                        .padding(5)
                case .appearance:
                    SymbolNodeAppearanceView(component: component, symbol: symbol)
                        .padding(5)
                }
            }
        }

    }
}
