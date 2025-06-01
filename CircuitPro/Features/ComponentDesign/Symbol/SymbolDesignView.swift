import SwiftUI

struct SymbolDesignView: View {
    @Environment(CanvasManager.self)
    private var canvasManager
    @Environment(\.componentDesignManager)
    private var componentDesignManager
    var body: some View {
        @Bindable var bindableComponentDesignManager = componentDesignManager
        CanvasView(
            manager: canvasManager,
            elements: $bindableComponentDesignManager.symbolElements,
            selectedIDs: $bindableComponentDesignManager.selectedSymbolElementIDs,
            selectedTool: $bindableComponentDesignManager.selectedSymbolTool,
            selectedLayer: .constant(.copper),
            layerAssignments: .constant([.init(): .copper])
        )
        .clipAndStroke(with: .rect(cornerRadius: 20))
        .overlay {
            CanvasOverlayView {
                SymbolDesignToolbarView()
            }
            .padding(10)
        }
    }
}
