//
//  SidebarTabView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/28/25.
//

import SwiftUI

struct SidebarTabView<T: SidebarTab>: View {
    
    @Binding var selectedTab: T
    var availableTabs: [T]
    
    var body: some View {
        VStack(spacing: 0) {
            Divider().foregroundStyle(.quaternary)
            if availableTabs.count > 1 {
                HStack(spacing: 4) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Image(systemName: tab.icon)
                                .frame(width: 28, height: 28)
                                .contentShape(.rect)
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
