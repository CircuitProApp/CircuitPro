//
//  SymbolNodeInspectorHostView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftDataPacks
import SwiftUI

struct SymbolNodeInspectorHostView: View {

    var component: ComponentInstance

    @Binding var selectedTab: InspectorTab

    private let availableTabs: [InspectorTab] = [.attributes, .appearance]

    var body: some View {
        SidebarView(selectedTab: $selectedTab, availableTabs: availableTabs) {
            ScrollView {
                switch selectedTab {
                case .attributes:
                    SymbolNodeAttributesView(component: component)
                        .padding(5)
                case .appearance:
                    SymbolNodeAppearanceView(component: component)
                        .padding(5)
                }
            }
        }

    }
}
