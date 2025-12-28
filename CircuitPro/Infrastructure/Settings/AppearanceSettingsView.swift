//
//  AppearanceSettingsView.swift
//  CircuitPro
//
//  Created by Codex on 9/21/25.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppThemeKeys.appearance) private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppThemeKeys.canvasStyleList) private var stylesData = CanvasStyleStore
        .defaultStylesData
    @AppStorage(AppThemeKeys.canvasStyleSelectedLight) private var selectedLightStyleID =
        CanvasStyleStore.defaultSelectedLightID
    @AppStorage(AppThemeKeys.canvasStyleSelectedDark) private var selectedDarkStyleID =
        CanvasStyleStore.defaultSelectedDarkID
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
        let currentID = editStyleID ?? activeSelectionID()
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
                VStack(spacing: 12) {
                    Picker("", selection: $assignMode) {
                        ForEach(AssignMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            CanvasAddSwatch(action: duplicateSelectedStyle)
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
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 5.0, for: .scrollContent)
                    .scrollClipDisabled()

                }

                TextField(
                    "Name",
                    text: Binding(
                        get: { selectedStyle.name },
                        set: { newValue in
                            updateSelectedStyle { style in
                                style.name = newValue
                            }
                        }
                    )
                )
                .disabled(selectedStyle.isBuiltin)

                CanvasColorPickerView(
                    title: "Background",
                    hex: hexBinding(for: \.backgroundHex),
                    showReset: isFieldModified(.background),
                    onReset: { resetSelectedField(.background) }
                )

                CanvasColorPickerView(
                    title: "Grid Marks",
                    hex: hexBinding(for: \.gridHex),
                    showReset: isFieldModified(.grid),
                    onReset: { resetSelectedField(.grid) }
                )

                CanvasColorPickerView(
                    title: "Text",
                    hex: hexBinding(for: \.textHex),
                    showReset: isFieldModified(.text),
                    onReset: { resetSelectedField(.text) }
                )

                CanvasColorPickerView(
                    title: "Markers",
                    hex: hexBinding(for: \.markerHex),
                    showReset: isFieldModified(.marker),
                    onReset: { resetSelectedField(.marker) }
                )

                CanvasColorPickerView(
                    title: "Crosshair & Marquee",
                    hex: hexBinding(for: \.crosshairHex),
                    showReset: isFieldModified(.crosshair),
                    onReset: { resetSelectedField(.crosshair) }
                )

                HStack {
                    Spacer()
                    if selectedStyle.isBuiltin {
                        Button("Reset to Default") { resetSelectedStyle() }
                            .disabled(!canResetSelectedStyle)
                    } else {
                        Button(role: .destructive) {
                            deleteSelectedStyle()
                        } label: {
                            Text("Delete Style")
                        }
                        .disabled(styles.count <= 1)
                    }
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
        .onAppear {
            let appAppearance = AppAppearance(rawValue: appearance) ?? .system
            switch appAppearance {
            case .light: assignMode = .light
            case .dark: assignMode = .dark
            case .system: assignMode = (colorScheme == .dark) ? .dark : .light
            }
        }
    }

    private func updateSelectedStyle(_ update: (inout CanvasStyle) -> Void) {
        var updatedStyles = styles
        guard updatedStyles.indices.contains(selectedIndex) else { return }
        update(&updatedStyles[selectedIndex])
        stylesData = CanvasStyleStore.encodeStyles(updatedStyles)
    }

    private func hexBinding(for keyPath: WritableKeyPath<CanvasStyle, String>) -> Binding<String> {
        Binding(
            get: { selectedStyle[keyPath: keyPath] },
            set: { newValue in
                updateSelectedStyle { style in
                    style[keyPath: keyPath] = newValue
                }
            }
        )
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
            crosshairHex: source.crosshairHex,
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
        if editStyleID == nil || !updatedStyles.contains(where: { $0.id.uuidString == editStyleID })
        {
            editStyleID = selectedLightStyleID
        }
    }

    private var canResetSelectedStyle: Bool {
        guard selectedStyle.isBuiltin, let defaults = defaultStyle(for: selectedStyle.id) else {
            return false
        }
        return selectedStyle != defaults
    }

    private func resetSelectedStyle() {
        guard selectedStyle.isBuiltin, let defaults = defaultStyle(for: selectedStyle.id) else {
            return
        }
        updateSelectedStyle { style in
            style.name = defaults.name
            style.backgroundHex = defaults.backgroundHex
            style.gridHex = defaults.gridHex
            style.textHex = defaults.textHex
            style.markerHex = defaults.markerHex
            style.crosshairHex = defaults.crosshairHex
        }
    }

    private func defaultStyle(for id: UUID) -> CanvasStyle? {
        CanvasStyleStore.defaultStyles.first(where: { $0.id == id })
    }

    private enum StyleField {
        case background
        case grid
        case text
        case marker
        case crosshair
    }

    private func isFieldModified(_ field: StyleField) -> Bool {
        guard selectedStyle.isBuiltin, let defaults = defaultStyle(for: selectedStyle.id) else {
            return false
        }
        switch field {
        case .background: return selectedStyle.backgroundHex != defaults.backgroundHex
        case .grid: return selectedStyle.gridHex != defaults.gridHex
        case .text: return selectedStyle.textHex != defaults.textHex
        case .marker: return selectedStyle.markerHex != defaults.markerHex
        case .crosshair: return selectedStyle.crosshairHex != defaults.crosshairHex
        }
    }

    private func resetSelectedField(_ field: StyleField) {
        guard selectedStyle.isBuiltin, let defaults = defaultStyle(for: selectedStyle.id) else {
            return
        }
        updateSelectedStyle { style in
            switch field {
            case .background:
                style.backgroundHex = defaults.backgroundHex
            case .grid:
                style.gridHex = defaults.gridHex
            case .text:
                style.textHex = defaults.textHex
            case .marker:
                style.markerHex = defaults.markerHex
            case .crosshair:
                style.crosshairHex = defaults.crosshairHex
            }
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

private struct CanvasAddSwatch: View {
    var action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.secondary)

                Image(systemName: "plus")
                    .imageScale(.large)
                    .fontWeight(.bold)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}
