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

            if availableTabs.count > 1 {
                Picker("Inspector Tab", selection: $selectedTab) {
                    ForEach(availableTabs) { tab in
                        Image(systemName: tab.iconName)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.large)
                .buttonSizing(.flexible)
                .padding(.horizontal, 8)
            }

            content
        }
    }
}
