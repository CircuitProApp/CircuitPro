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
    @AppStorage(AppThemeKeys.canvasStyleList) private var stylesData = CanvasStyleStore.defaultStylesData
    @AppStorage(AppThemeKeys.canvasStyleSelected) private var selectedStyleID = CanvasStyleStore.defaultSelectedID

    private var styles: [CanvasStyle] {
        CanvasStyleStore.loadStyles(from: stylesData)
    }

    private var selectedIndex: Int {
        styles.firstIndex(where: { $0.id.uuidString == selectedStyleID }) ?? 0
    }

    private var selectedStyle: CanvasStyle {
        styles[selectedIndex]
    }

    var body: some View {
        Form {
            Section("App ") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Canvas Style") {
                Picker("Style", selection: $selectedStyleID) {
                    ForEach(styles) { style in
                        Text(style.name).tag(style.id.uuidString)
                    }
                }

                HStack {
                    Button("New Style") { duplicateSelectedStyle() }
                    Button("Delete Style") { deleteSelectedStyle() }
                        .disabled(selectedStyle.isBuiltin || styles.count <= 1)
                }

                TextField("Name", text: Binding(
                    get: { selectedStyle.name },
                    set: { newValue in
                        updateSelectedStyle { style in
                            style.name = newValue
                        }
                    }
                ))
                .disabled(selectedStyle.isBuiltin)

                ColorPicker(
                    "Background",
                    selection: Binding(
                        get: { Color(hex: selectedStyle.backgroundHex) },
                        set: { newValue in
                            updateSelectedStyle { style in
                                style.backgroundHex = newValue.toHexRGBA()
                            }
                        }
                    )
                )
                ColorPicker(
                    "Grid Marks",
                    selection: Binding(
                        get: { Color(hex: selectedStyle.gridHex) },
                        set: { newValue in
                            updateSelectedStyle { style in
                                style.gridHex = newValue.toHexRGBA()
                            }
                        }
                    )
                )
                ColorPicker(
                    "Text",
                    selection: Binding(
                        get: { Color(hex: selectedStyle.textHex) },
                        set: { newValue in
                            updateSelectedStyle { style in
                                style.textHex = newValue.toHexRGBA()
                            }
                        }
                    )
                )
                ColorPicker(
                    "Markers",
                    selection: Binding(
                        get: { Color(hex: selectedStyle.markerHex) },
                        set: { newValue in
                            updateSelectedStyle { style in
                                style.markerHex = newValue.toHexRGBA()
                            }
                        }
                    )
                )
            }
        }
        .navigationTitle("Appearance")
        .formStyle(.grouped)
        .onChange(of: stylesData) { _ in
            let loaded = CanvasStyleStore.loadStyles(from: stylesData)
            if !loaded.contains(where: { $0.id.uuidString == selectedStyleID }) {
                selectedStyleID = loaded[0].id.uuidString
            }
        }
    }

    private func updateSelectedStyle(_ update: (inout CanvasStyle) -> Void) {
        var updatedStyles = styles
        guard updatedStyles.indices.contains(selectedIndex) else { return }
        update(&updatedStyles[selectedIndex])
        stylesData = CanvasStyleStore.encodeStyles(updatedStyles)
    }

    private func duplicateSelectedStyle() {
        var updatedStyles = styles
        let source = selectedStyle
        let copy = CanvasStyle(
            id: UUID(),
            name: "\(source.name) Copy",
            backgroundHex: source.backgroundHex,
            gridHex: source.gridHex,
            textHex: source.textHex,
            markerHex: source.markerHex,
            isBuiltin: false
        )
        updatedStyles.append(copy)
        stylesData = CanvasStyleStore.encodeStyles(updatedStyles)
        selectedStyleID = copy.id.uuidString
    }

    private func deleteSelectedStyle() {
        guard !selectedStyle.isBuiltin else { return }
        var updatedStyles = styles
        updatedStyles.removeAll { $0.id == selectedStyle.id }
        if updatedStyles.isEmpty {
            updatedStyles = CanvasStyleStore.defaultStyles
        }
        stylesData = CanvasStyleStore.encodeStyles(updatedStyles)
        selectedStyleID = updatedStyles[0].id.uuidString
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
