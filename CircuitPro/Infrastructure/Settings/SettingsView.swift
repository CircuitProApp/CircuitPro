//
//  SettingsView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftUI

private enum SettingsRoute: Hashable {
    case appearance
    case test
}

struct SettingsView: View {
    @State private var selection: SettingsRoute? = .appearance

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: SettingsRoute.appearance) {
                    Label {
                        Text("Appearance")
                    } icon: {

                        Image(systemName: "circle")
                            .padding(3)
                            .background(.black.gradient)
                            .clipShape(.rect(cornerRadius: 5))
                    }
                }
                NavigationLink(value: SettingsRoute.test) {
                    Label("Test", systemImage: "gearshape")
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
                        case .test:
                            TestSettingsView()
                        }
                    }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

private struct TestSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("This is a placeholder screen for the settings navigation.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .navigationTitle("Test")
    }
}
