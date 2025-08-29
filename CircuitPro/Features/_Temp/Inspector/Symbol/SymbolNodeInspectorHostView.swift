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
    @Bindable var symbolNode: SymbolNode
    
    @Binding var selectedTab: InspectorTab
    
    private let availableTabs: [InspectorTab] = [.attributes, .appearance]
    
    var body: some View {
        SidebarView(selectedTab: $selectedTab, availableTabs: availableTabs) {
            ScrollView {
                switch selectedTab {
                case .attributes:
                    SymbolNodeAttributesView(component: component, symbolNode: symbolNode)
                        .padding(5)
                case .appearance:
                    SymbolNodeAppearanceView(component: component, symbolNode: symbolNode)
                        .padding(5)
                }
            }
        }
       
    }
}
