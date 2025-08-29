//
//  SymbolNodeInspectorHostView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftUI
import SwiftDataPacks

struct SymbolNodeInspectorHostView: View {
    
    let component: ComponentInstance
    @Bindable var symbolNode: SymbolNode
    
    // This binding allows the parent InspectorView to control and remember the selected tab
    @Binding var selectedTab: InspectorTab
    
    // Define which tabs are relevant for a SymbolNode
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
