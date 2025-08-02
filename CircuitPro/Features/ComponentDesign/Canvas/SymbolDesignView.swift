import SwiftUI

struct SymbolDesignView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    @Environment(\.componentDesignManager)
    private var componentDesignManager
    
    @State private var isCollapsed: Bool = true

    var body: some View {

        @Bindable var symbolEditor = componentDesignManager.symbolEditor

        SplitPaneView(isCollapsed: $isCollapsed) {
            CanvasView(
                manager: canvasManager, schematicGraph: .init(),
                elements: $symbolEditor.elements,
                selectedIDs: $symbolEditor.selectedElementIDs,
                selectedTool: $symbolEditor.selectedTool
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
