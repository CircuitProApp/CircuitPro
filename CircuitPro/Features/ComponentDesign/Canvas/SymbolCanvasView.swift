import SwiftUI

struct SymbolCanvasView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
    @State private var isCollapsed: Bool = true

    var body: some View {

        @Bindable var symbolEditor = componentDesignManager.symbolEditor

        SplitPaneView(isCollapsed: $isCollapsed) {
            // The CanvasView call is now updated to use the new properties.
            CanvasView(
                manager: canvasManager,
                selectedIDs: $symbolEditor.selectedElementIDs,
                selectedTool: $symbolEditor.selectedTool,
                nodes: $symbolEditor.elements
            )
            .overlay(alignment: .leading) {
                SymbolDesignToolbarView()
                    .padding(10)
            }
        } handle: {
            HStack {
                CanvasControlView(editorType: .layout)
                Spacer()
                GridSpacingControlView()
                ZoomControlView()
            }
        } secondary: {
            Text("WIP")
        }
    }
}
