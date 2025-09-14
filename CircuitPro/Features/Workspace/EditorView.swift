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

    var document: CircuitProjectFileDocument

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
            if projectManager.selectedDesign != nil {
                editorSelection
            }

            SplitPaneView(isCollapsed: $showUtilityArea) {
                if projectManager.selectedDesign == nil {
                    Text("Select a design")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch selectedEditor {
                    case .schematic:
                        SchematicCanvasView(document: document, canvasManager: selectedCanvasManager)
                    case .layout:
                        LayoutView(document: document)
                    }
                }

            } handle: {
                CanvasStatusBarView(isCollapsed: $showUtilityArea, configuration: selectedEditor == .schematic ? .fixedGrid : .default)
            } secondary: {
                UtilityAreaView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(selectedCanvasManager)
        // --- ADDED: Trigger rebuild when the editor changes ---
        .onChange(of: projectManager.selectedEditor) {
            projectManager.rebuildActiveCanvasNodes()
        }
    }

    private var editorSelection: some View {
        Group {
            HStack {
                Spacer()
                Button {
                    projectManager.selectedEditor = .schematic
                } label: {
                    Text("Schematic")
                        .directionalPadding(vertical: 3, horizontal: 7.5)
                        .background(
                            selectedEditor == .schematic ?
                            AnyShapeStyle(Color.blue.quaternary) : AnyShapeStyle(Color.clear)
                        )
                        .foregroundStyle(selectedEditor == .schematic ? .blue : .secondary)
                        .clipShape(.rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button {
                    projectManager.selectedEditor = .layout
                } label: {
                    Text("Layout")
                        .directionalPadding(vertical: 3, horizontal: 7.5)
                        .background(
                            selectedEditor == .layout ?
                            AnyShapeStyle(Color.blue.quaternary) : AnyShapeStyle(Color.clear)
                        )
                        .foregroundStyle(selectedEditor == .layout ? .blue : .secondary)
                        .clipShape(.rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .frame(height: 29)
            .frame(maxWidth: .infinity)
            .font(.system(size: 11))

            Divider()
                .foregroundStyle(.quaternary)
        }
    }
}
