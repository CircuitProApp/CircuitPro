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
    @AppStorage(AppThemeKeys.canvasStyleSelectedLight) private var selectedLightStyleID = CanvasStyleStore.defaultSelectedLightID
    @AppStorage(AppThemeKeys.canvasStyleSelectedDark) private var selectedDarkStyleID = CanvasStyleStore.defaultSelectedDarkID
    @State private var editStyleID: String?
    @State private var assignMode: AssignMode = .light

    private enum AssignMode: String, CaseIterable, Identifiable {
        case light
        case dark

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    private var styles: [CanvasStyle] {
        CanvasStyleStore.loadStyles(from: stylesData)
    }

    private var selectedIndex: Int {
        let currentID = editStyleID ?? selectedLightStyleID
        return styles.firstIndex(where: { $0.id.uuidString == currentID }) ?? 0
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
                    Picker("", selection: $assignMode) {
                        ForEach(AssignMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Spacer()

                    HStack(spacing: 12) {
                        ForEach(styles) { style in
                            CanvasStyleSwatch(
                                style: style,
                                isSelected: style.id.uuidString == activeSelectionID(),
                                isLightAssigned: style.id.uuidString == selectedLightStyleID,
                                isDarkAssigned: style.id.uuidString == selectedDarkStyleID
                            )
                            .onTapGesture {
                                applySelection(styleID: style.id.uuidString)
                            }
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
                    Spacer()
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
            if !loaded.contains(where: { $0.id.uuidString == selectedLightStyleID }) {
                selectedLightStyleID = loaded[0].id.uuidString
            }
            if !loaded.contains(where: { $0.id.uuidString == selectedDarkStyleID }) {
                selectedDarkStyleID = loaded[0].id.uuidString
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
        editStyleID = copy.id.uuidString
        applySelection(styleID: copy.id.uuidString)
    }

    private func deleteSelectedStyle() {
        guard !selectedStyle.isBuiltin else { return }
        var updatedStyles = styles
        updatedStyles.removeAll { $0.id == selectedStyle.id }
        if updatedStyles.isEmpty {
            updatedStyles = CanvasStyleStore.defaultStyles
        }
        stylesData = CanvasStyleStore.encodeStyles(updatedStyles)
        if !updatedStyles.contains(where: { $0.id.uuidString == selectedLightStyleID }) {
            selectedLightStyleID = updatedStyles[0].id.uuidString
        }
        if !updatedStyles.contains(where: { $0.id.uuidString == selectedDarkStyleID }) {
            selectedDarkStyleID = updatedStyles[0].id.uuidString
        }
        if editStyleID == nil || !updatedStyles.contains(where: { $0.id.uuidString == editStyleID }) {
            editStyleID = selectedLightStyleID
        }
    }

    private func activeSelectionID() -> String {
        switch assignMode {
        case .light:
            return selectedLightStyleID
        case .dark:
            return selectedDarkStyleID
        }
    }

    private func applySelection(styleID: String) {
        editStyleID = styleID
        switch assignMode {
        case .light:
            selectedLightStyleID = styleID
        case .dark:
            selectedDarkStyleID = styleID
        }
    }
}

private struct CanvasStyleSwatch: View {
    let style: CanvasStyle
    let isSelected: Bool
    let isLightAssigned: Bool
    let isDarkAssigned: Bool
    @State private var isHovered = false

    var body: some View {
        let background = Color(hex: style.backgroundHex)
        let grid = Color(hex: style.gridHex)
        let ring = Color(hex: style.backgroundHex)
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
                    .stroke(isSelected ? ring : Color.clear, lineWidth: 3)
                    .padding(-4)
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
            .onHover { hovering in
                isHovered = hovering
            }

            ZStack {
                if showsLabel && isLightAssigned && isDarkAssigned {
                    HStack(spacing: 4) {
                        Text(style.name)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "sun.max.fill")
                        Image(systemName: "moon.fill")
                    }
                    .font(.caption2)
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                } else {
                    Text(style.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(showsLabel ? 1 : 0)
                }

                HStack(spacing: 4) {
                    if isLightAssigned {
                        Image(systemName: "sun.max.fill")
                    }
                    if isDarkAssigned {
                        Image(systemName: "moon.fill")
                    }
                }
                .font(.caption2)
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .opacity(showsLabel || (!isLightAssigned && !isDarkAssigned) ? 0 : 1)
            }
            .frame(width: 56)
        }
    }
}
