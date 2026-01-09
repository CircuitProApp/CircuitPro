//
//  EditorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import AppKit
import SwiftUI

struct EditorView: View {

    @BindableEnvironment(\.editorSession)
    private var editorSession

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage(AppThemeKeys.canvasStyleList) private var stylesData = CanvasStyleStore
        .defaultStylesData
    @AppStorage(AppThemeKeys.canvasStyleSelectedLight) private var selectedLightStyleID =
        CanvasStyleStore.defaultSelectedLightID
    @AppStorage(AppThemeKeys.canvasStyleSelectedDark) private var selectedDarkStyleID =
        CanvasStyleStore.defaultSelectedDarkID

    @State private var showUtilityArea: Bool = true

    @State private var schematicCanvasManager = CanvasManager()
    @State private var layoutCanvasManager = CanvasManager()

    var selectedEditor: EditorType {
        editorSession.selectedEditor
    }

    var selectedCanvasManager: CanvasManager {
        switch selectedEditor {
        case .schematic:
            return schematicCanvasManager
        case .layout:
            return layoutCanvasManager
        }
    }

    var body: some View {
        Group {
            switch selectedEditor {
            case .schematic:
                SchematicCanvasView(canvasManager: selectedCanvasManager)
                    .id("schematic-canvas")
            case .layout:
                LayoutCanvasView(canvasManager: selectedCanvasManager)
                    .id("layout-canvas")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(selectedCanvasManager)
        .onAppear { applyThemes() }
        .onChange(of: stylesData) { applyThemes() }
        .onChange(of: selectedLightStyleID) { applyThemes() }
        .onChange(of: selectedDarkStyleID) { applyThemes() }
        .onChange(of: colorScheme) { applyThemes() }
    }

    private func applyThemes() {
        let style = selectedStyle()
        let canvasTheme = CanvasThemeSettings.makeTheme(from: style)
        let schematicTheme = SchematicThemeSettings.makeTheme(from: style)
        schematicCanvasManager.applyTheme(canvasTheme)
        schematicCanvasManager.applySchematicTheme(schematicTheme)
        layoutCanvasManager.applyTheme(canvasTheme)
    }

    private func selectedStyle() -> CanvasStyle {
        let styles = CanvasStyleStore.loadStyles(from: stylesData)
        let selectedID = colorScheme == .dark ? selectedDarkStyleID : selectedLightStyleID
        return CanvasStyleStore.selectedStyle(from: styles, selectedID: selectedID)
    }
}
