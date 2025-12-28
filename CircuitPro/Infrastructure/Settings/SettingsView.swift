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
                    Label("Appearance", systemImage: "paintbrush")
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

private struct AppearanceSettingsView: View {
    @AppStorage(AppThemeKeys.appearance) private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppThemeKeys.canvasBackground) private var canvasBackground = AppThemeDefaults.canvasBackground
    @AppStorage(AppThemeKeys.gridDots) private var gridDots = AppThemeDefaults.gridDots

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { Color(hex: canvasBackground) },
            set: { canvasBackground = $0.toHexRGBA() }
        )
    }

    private var gridDotsBinding: Binding<Color> {
        Binding(
            get: { Color(hex: gridDots) },
            set: { gridDots = $0.toHexRGBA() }
        )
    }

    var body: some View {
        Form {
            Section("App Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Canvas") {
                ColorPicker("Background", selection: backgroundBinding)
                ColorPicker("Grid Dots", selection: gridDotsBinding)
            }
        }

        .navigationTitle("Appearance")
        .formStyle(.grouped)
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
