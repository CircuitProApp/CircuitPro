//
//  AppearanceSettingsView.swift
//  CircuitPro
//
//  Created by Codex on 9/21/25.
//

import SwiftUI

struct AppearanceSettingsView: View {
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
            Section {
                Picker("App", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Canvas") {
                HStack(spacing: 12) {
                    Text("Theme")
                    Spacer()
                    ForEach(styles) { style in
                        CanvasStyleSwatch(
                            style: style,
                            isSelected: style.id.uuidString == selectedStyleID
                        )
                        .onTapGesture {
                            selectedStyleID = style.id.uuidString
                        }
                    }
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

                HStack {
                    Button("New Style") { duplicateSelectedStyle() }
                    Button("Delete Style") { deleteSelectedStyle() }
                        .disabled(selectedStyle.isBuiltin || styles.count <= 1)
                }
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

private struct CanvasStyleSwatch: View {
    let style: CanvasStyle
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        let background = Color(hex: style.backgroundHex)
        let grid = Color(hex: style.gridHex)
        let showsLabel = isSelected || isHovered

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(background)
                    .overlay(
                        Circle()
                            .stroke(grid, lineWidth: 2)
                    )

                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    .padding(-4)
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .onHover { hovering in
                isHovered = hovering
            }

            Text(style.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 56)
                .opacity(showsLabel ? 1 : 0)
        }
    }
}
