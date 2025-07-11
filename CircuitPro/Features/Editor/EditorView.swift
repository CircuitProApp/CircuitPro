import SwiftUI
import AppKit

struct EditorView: View {

    @Environment(\.projectManager)
    private var projectManager

    var document: CircuitProjectDocument

    @State private var showUtilityArea: Bool = false

    @State private var selectedEditor: EditorType = .schematic

    @State private var schematicCanvasManager = CanvasManager()
    @State private var layoutCanvasManager = CanvasManager()

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

            SplitView(showBottomView: $showUtilityArea) {
                if projectManager.selectedDesign == nil {
                    Text("Select a design")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch selectedEditor {
                    case .schematic:
                        SchematicView(document: document, canvasManager: selectedCanvasManager)
                    case .layout:
                        LayoutView()
                    }
                }

            } dividerView: {
                StatusBarView(
                    canvasManager: selectedCanvasManager,
                    editorType: selectedEditor,
                    showUtilityArea: $showUtilityArea
                )
            } bottomView: {
                UtilityAreaView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(selectedCanvasManager)
    }

    private var editorSelection: some View {
        Group {
            HStack {
                Spacer()
                Button {
                    selectedEditor = .schematic
                } label: {
                    Text("Schematic")
                        .directionalPadding(vertical: 3, horizontal: 7.5)
                        .background(
                            selectedEditor == .schematic ?
                            AnyShapeStyle(Color.blue.quaternary) : AnyShapeStyle(Color.clear)
                        )
                        .foregroundStyle(selectedEditor == .schematic ? .primary : .secondary)
                        .clipShape(.rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button {
                    selectedEditor = .layout
                } label: {
                    Text("Layout")
                        .directionalPadding(vertical: 3, horizontal: 7.5)
                        .background(
                            selectedEditor == .layout ?
                            AnyShapeStyle(Color.blue.quaternary) : AnyShapeStyle(Color.clear)
                        )
                        .foregroundStyle(selectedEditor == .layout ? .primary : .secondary)
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
