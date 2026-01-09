//
//  SettingsView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var selection: SettingsRoute? = .appearance

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsRoute.allCases, id: \.self) { route in
                    NavigationLink(value: route) {
                        settingsLabel(title: route.label, icon: route.iconName, color: route.iconColor)
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
    
    private func settingsLabel(title: String, icon: String, color: Color) -> some View {
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
