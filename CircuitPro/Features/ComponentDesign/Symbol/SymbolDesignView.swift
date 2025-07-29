import SwiftUI

struct SymbolDesignView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    @Environment(\.componentDesignManager)
    private var componentDesignManager
    
    @State private var isCollapsed: Bool = true

    var body: some View {

        @Bindable var bindableComponentDesignManager = componentDesignManager

        SplitPaneView(isCollapsed: $isCollapsed) {
            CanvasView(
                manager: canvasManager, schematicGraph: .init(),
                elements: $bindableComponentDesignManager.symbolElements,
                selectedIDs: $bindableComponentDesignManager.selectedSymbolElementIDs,
                selectedTool: $bindableComponentDesignManager.selectedSymbolTool
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
