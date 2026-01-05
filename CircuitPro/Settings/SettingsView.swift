//
//  SettingsView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftUI

private enum SettingsRoute: String, Hashable, CaseIterable {
    case appearance

    var label: String {
        switch self {
        case .appearance: return "Appearance"
        }
    }

    var iconName: String {
        switch self {
        case .appearance: return "paintbrush"
        }
    }

    var iconColor: Color {
        switch self {
        case .appearance: return .blue
        }
    }
}

struct SettingsView: View {
    @State private var selection: SettingsRoute? = .appearance

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsRoute.allCases, id: \.self) { route in
                    NavigationLink(value: route) {
                        SettingsLabel(
                            title: route.label, icon: route.iconName, color: route.iconColor)
                    }
                }
            }
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                AppearanceSettingsView()
                    .navigationDestination(for: SettingsRoute.self) { route in
                        switch route {
                        case .appearance:
                            AppearanceSettingsView()
                        }
                    }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

private struct SettingsLabel: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .padding(4)
                .frame(width: 22, height: 22)
                .background(color.gradient)
                .clipShape(.rect(cornerRadius: 5))
        }
    }
}
