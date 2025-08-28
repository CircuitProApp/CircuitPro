//
//  SidebarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/28/25.
//

import SwiftUI

struct SidebarView<T: SidebarTab, Content: View>: View {
    
    @Binding var selectedTab: T
    var availableTabs: [T]
    
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            SidebarTabView(selectedTab: $selectedTab, availableTabs: availableTabs)
            content
        }
    }
}
