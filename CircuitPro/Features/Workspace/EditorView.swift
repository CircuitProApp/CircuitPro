//
//  EditorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import AppKit
import SwiftUI

struct EditorView: View {

    @Environment(\.projectManager)
    private var projectManager

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage(AppThemeKeys.appearance) private var appearance = AppAppearance.system.rawValue
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
        projectManager.selectedEditor
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
        VStack(spacing: 0) {
            SplitPaneView(isCollapsed: $showUtilityArea) {
                switch selectedEditor {
                case .schematic:
                    SchematicCanvasView(canvasManager: selectedCanvasManager)
                        .id("schematic-canvas")
                case .layout:
                    LayoutCanvasView(canvasManager: selectedCanvasManager)
                        .id("layout-canvas")
                }

            } handle: {
                CanvasStatusBarView(
                    isCollapsed: $showUtilityArea,
                    configuration: selectedEditor == .schematic ? .fixedGrid : .default)
            } secondary: {
                UtilityAreaView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(selectedCanvasManager)
        .onAppear { applyCanvasTheme() }
        .onChange(of: appearance) { applyCanvasTheme() }
        .onChange(of: stylesData) { applyCanvasTheme() }
        .onChange(of: selectedLightStyleID) { applyCanvasTheme() }
        .onChange(of: selectedDarkStyleID) { applyCanvasTheme() }
        .onChange(of: colorScheme) { applyCanvasTheme() }
    }

    private func applyCanvasTheme() {
        let styles = CanvasStyleStore.loadStyles(from: stylesData)
        let appAppearance = AppAppearance(rawValue: appearance) ?? .system
        let effectiveScheme: ColorScheme = {
            switch appAppearance {
            case .system: return colorScheme
            case .light: return .light
            case .dark: return .dark
            }
        }()
        let selectedID = effectiveScheme == .dark ? selectedDarkStyleID : selectedLightStyleID
        let style = CanvasStyleStore.selectedStyle(from: styles, selectedID: selectedID)
        let theme = CanvasThemeSettings.makeTheme(from: style)
        schematicCanvasManager.applyTheme(theme)
        layoutCanvasManager.applyTheme(theme)
    }
}
