//
//  EditorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI
import AppKit

struct EditorView: View {

    @Environment(\.projectManager)
    private var projectManager

    @AppStorage(AppThemeKeys.canvasBackground) private var canvasBackground = AppThemeDefaults.canvasBackground
    @AppStorage(AppThemeKeys.gridDots) private var gridDots = AppThemeDefaults.gridDots

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
                case .layout:
                    LayoutCanvasView(canvasManager: selectedCanvasManager)
                }

            } handle: {
                CanvasStatusBarView(isCollapsed: $showUtilityArea, configuration: selectedEditor == .schematic ? .fixedGrid : .default)
            } secondary: {
                UtilityAreaView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(selectedCanvasManager)
        .onAppear { applyCanvasTheme() }
        .onChange(of: canvasBackground) { applyCanvasTheme() }
        .onChange(of: gridDots) { applyCanvasTheme() }
    }

    private func applyCanvasTheme() {
        let theme = CanvasThemeSettings.makeTheme(backgroundHex: canvasBackground, gridDotsHex: gridDots)
        schematicCanvasManager.applyTheme(theme)
        layoutCanvasManager.applyTheme(theme)
    }
}
