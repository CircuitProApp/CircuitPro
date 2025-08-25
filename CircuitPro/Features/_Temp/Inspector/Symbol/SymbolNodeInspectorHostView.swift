//
//  SymbolNodeInspectorHostView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftUI
import SwiftDataPacks

struct SymbolNodeInspectorHostView: View {
    
    let component: DesignComponent
    @Bindable var symbolNode: SymbolNode
    
    // This binding allows the parent InspectorView to control and remember the selected tab
    @Binding var selectedTab: InspectorTab
    
    // Define which tabs are relevant for a SymbolNode
    private let availableTabs: [InspectorTab] = [.attributes, .appearance]
    
    var body: some View {
        VStack(spacing: 0) {
           inspectorTab
            
            ScrollView {
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .attributes:
                        SymbolNodeAttributesView(component: component, symbolNode: symbolNode)
                    case .appearance:
                        SymbolNodeAppearanceView(component: component, symbolNode: symbolNode)
                    }
                }
            }
            .contentMargins(5)
        }
    }
    
    
    private var inspectorTab: some View {
        Group {
            if availableTabs.count > 1 {
                Divider().foregroundStyle(.quaternary)
                HStack(spacing: 17) {
                    ForEach(InspectorTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Image(systemName: tab.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 13, height: 13)
                                .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                                .symbolVariant(selectedTab == tab ? .fill : .none)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .foregroundStyle(.secondary)
                
                Divider().foregroundStyle(.quaternary)
            }
        }
    }
}
