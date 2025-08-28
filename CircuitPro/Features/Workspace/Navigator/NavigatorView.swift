//
//  NavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI

struct NavigatorView: View {

    @State private var selectedTab: NavigatorTab = .projectNavigator
    var document: CircuitProjectFileDocument

    var body: some View {
        SidebarView(selectedTab: $selectedTab, availableTabs: [.projectNavigator]) {
            switch selectedTab {
            case .projectNavigator:
                ProjectNavigatorView(document: document)
            default:
                Group {
                    Text("Default")
                    Spacer()
                }
            }
        }
    }
}
