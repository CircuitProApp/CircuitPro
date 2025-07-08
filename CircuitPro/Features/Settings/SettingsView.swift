//
//  SettingsView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftUI

enum SettingsTab: String, CaseIterable {
    case board
    case schematic
    case layout

    var icon: String {
        switch self {
        case .board:
            return CircuitProSymbols.Project.board
        case .schematic:
            return CircuitProSymbols.Project.schematic
        case .layout:
            return CircuitProSymbols.Project.layout
        }
    }
}

struct SettingsView: View {

    @State private var selectedTab: SettingsTab = .board

    var body: some View {
        VStack {
            switch selectedTab {
            case .board:
                BoardSettingsView()
            case .schematic:
                Text("Schematic Settings")
            case .layout:
                Text("Layout Settings")
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 40) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack {
                                Image(systemName: tab.icon)
                                Text(tab.rawValue.capitalized)
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.title2)
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
