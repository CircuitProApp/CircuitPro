import SwiftUI

struct SymbolDesignView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    @Environment(\.componentDesignManager)
    private var componentDesignManager

    var body: some View {

        @Bindable var bindableComponentDesignManager = componentDesignManager

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
        .overlay(alignment: .bottom) {
            HStack {
                CanvasControlView(editorType: .layout)
                Spacer()
                GridSpacingControlView()
                ZoomControlView()
            }
            .padding(10)
            .background(.ultraThinMaterial)

        }
        .clipAndStroke(with: .rect(cornerRadius: 20))
    }
}
